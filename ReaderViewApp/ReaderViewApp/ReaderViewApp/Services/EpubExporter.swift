import Foundation
import ZIPFoundation

/// Builds a minimal EPUB for a single article with images saved as separate files.
final class EpubExporter {
    private let iso8601 = ISO8601DateFormatter()
    private let session: URLSession
    private let maxImageBytes = 8_000_000 // Skip extremely large assets to avoid memory spikes
    private let fetchTimeout: TimeInterval = 12
    
    struct ImageResource {
        let filename: String
        let data: Data
        let mimeType: String
    }
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    func export(article: Article) async throws -> URL {
        let baseURL = URL(string: article.url)
        var images: [ImageResource] = []
        let htmlWithLocalImages = await extractAndReplaceImages(in: article.content, baseURL: baseURL, images: &images)
        let xhtml = xhtmlDocument(bodyHTML: htmlWithLocalImages, article: article)
        let opf = opfDocument(article: article, images: images)
        let nav = navDocument(title: article.title)
        let css = stylesheet()
        let containerXML = containerDocument()
        let mimetypeData = Data("application/epub+zip".utf8)
        
        var files: [(path: String, data: Data, compressed: Bool)] = [
            ("META-INF/container.xml", Data(containerXML.utf8), true),
            ("OEBPS/content.opf", Data(opf.utf8), true),
            ("OEBPS/style.css", Data(css.utf8), true),
            ("OEBPS/nav.xhtml", Data(nav.utf8), true),
            ("OEBPS/index.xhtml", Data(xhtml.utf8), true)
        ]
        
        // Add image files
        for image in images {
            files.append(("OEBPS/images/\(image.filename)", image.data, true))
        }
        
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("ReaderView-EPUB-\(UUID().uuidString).epub")
        let archive = try Archive(url: outputURL, accessMode: .create)
        
        try archive.addEntry(with: "mimetype", type: .file, uncompressedSize: Int64(mimetypeData.count), compressionMethod: .none, bufferSize: 16 * 1024) { position, size in
            let start = Int(position)
            let end = start + size
            return mimetypeData.subdata(in: start..<end)
        }

        for file in files {
            try archive.addEntry(with: file.path, type: .file, uncompressedSize: Int64(file.data.count), compressionMethod: file.compressed ? .deflate : .none, bufferSize: 32 * 1024) { position, size in
                let start = Int(position)
                let end = start + size
                return file.data.subdata(in: start..<end)
            }
        }
        
        return outputURL
    }
    
    private func extractAndReplaceImages(in html: String, baseURL: URL?, images: inout [ImageResource]) async -> String {
        guard let regex = try? NSRegularExpression(pattern: "<img[^>]*src=[\"']([^\"'>]+)[\"'][^>]*>", options: [.caseInsensitive]) else {
            return html
        }
        var result = html
        let matches = regex.matches(in: html, range: NSRange(location: 0, length: html.utf16.count)).reversed()
        var imageCounter = 1
        
        for match in matches {
            guard match.numberOfRanges >= 2, let range = Range(match.range(at: 1), in: html) else { continue }
            let src = String(html[range])
            
            // Skip if already a local path or data URI
            if src.hasPrefix("images/") || src.hasPrefix("data:") {
                continue
            }
            
            let resolvedURL: URL?
            if let absolute = URL(string: src), absolute.scheme?.hasPrefix("http") == true {
                resolvedURL = absolute
            } else if let base = baseURL {
                resolvedURL = URL(string: src, relativeTo: base)?.absoluteURL
            } else {
                resolvedURL = nil
            }
            guard let url = resolvedURL else { continue }
            
            do {
                var request = URLRequest(url: url)
                request.timeoutInterval = fetchTimeout
                let (data, response) = try await session.data(for: request)
                if data.count > maxImageBytes { continue }
                let mime = response.mimeType ?? mimeType(for: url)
                guard let mime, mime.hasPrefix("image/") else { continue }
                
                // Determine file extension
                let ext = self.fileExtension(for: mime)
                let filename = "image\(imageCounter).\(ext)"
                imageCounter += 1
                
                // Store image resource
                images.append(ImageResource(filename: filename, data: data, mimeType: mime))
                
                // Replace src with local path
                let localPath = "images/\(filename)"
                if let replaceRange = Range(match.range(at: 1), in: result) {
                    result.replaceSubrange(replaceRange, with: localPath)
                }
            } catch {
                continue
            }
        }
        // Remove responsive/loading attributes that may interfere with local paths in EPUB
        result = stripResponsiveImgAttributes(result)
        return result
    }

    private func stripResponsiveImgAttributes(_ html: String) -> String {
        var output = html
        // Remove attributes: srcset, sizes, loading, decoding, data-* from <img ...>
        // Do multiple passes to catch repeated attributes
        if let regex = try? NSRegularExpression(pattern: "(<img[^>]*)(\\s(?:srcset|sizes|loading|decoding|data-[^=]+)=\"[^\"]*\")", options: [.caseInsensitive]) {
            while true {
                let matches = regex.matches(in: output, range: NSRange(location: 0, length: output.utf16.count))
                if matches.isEmpty { break }
                var mutable = output
                for match in matches.reversed() {
                    let attrRange = match.range(at: 2)
                    if let swiftRange = Range(attrRange, in: output) {
                        mutable.removeSubrange(swiftRange)
                    }
                }
                output = mutable
            }
        }
        return output
    }
    
    private func fileExtension(for mimeType: String) -> String {
        switch mimeType {
        case "image/jpeg": return "jpg"
        case "image/png": return "png"
        case "image/gif": return "gif"
        case "image/webp": return "webp"
        case "image/svg+xml": return "svg"
        default: return "jpg"
        }
    }
    
    private func xhtmlDocument(bodyHTML: String, article: Article) -> String {
        let title = escape(article.title)
        let byline = article.byline.map { escape($0) }
        let siteName = article.siteName.map { escape($0) }
        let wordCount = article.length
        let dateString = iso8601.string(from: article.dateExtracted)
        let safeBody = normalizeVoidTags(replaceHTMLEntities(bodyHTML))
        return """
        <?xml version=\"1.0\" encoding=\"utf-8\"?>
        <!DOCTYPE html>
        <html xmlns=\"http://www.w3.org/1999/xhtml\" xml:lang=\"en\">
        <head>
            <meta charset=\"utf-8\" />
            <title>\(title)</title>
            <link rel=\"stylesheet\" type=\"text/css\" href=\"style.css\" />
        </head>
        <body>
            <header class=\"article-header\">
                <p class=\"eyebrow\">\(siteName ?? "")</p>
                <h1>\(title)</h1>
                <p class=\"meta\">\(byline ?? "")</p>
                <p class=\"meta\">\(wordCount) words · \(dateString)</p>
            </header>
            <article>
                \(safeBody)
            </article>
        </body>
        </html>
        """
    }
    
    private func opfDocument(article: Article, images: [ImageResource]) -> String {
        let identifier = article.id.uuidString
        let title = escape(article.title)
        let author = escape(article.byline ?? "")
        let modified = iso8601.string(from: article.dateExtracted)
        
        // Build image manifest entries
        var imageManifest = ""
        for (index, image) in images.enumerated() {
            let id = "img\(index + 1)"
            let href = "images/\(image.filename)"
            imageManifest += "\n            <item id=\"\(id)\" href=\"\(href)\" media-type=\"\(image.mimeType)\" />"
        }
        
        return """
        <?xml version=\"1.0\" encoding=\"utf-8\"?>
        <package xmlns=\"http://www.idpf.org/2007/opf\" unique-identifier=\"pub-id\" version=\"3.0\">
          <metadata xmlns:dc=\"http://purl.org/dc/elements/1.1/\" xmlns:dcterms=\"http://purl.org/dc/terms/\">
            <dc:identifier id=\"pub-id\">\(identifier)</dc:identifier>
            <dc:title>\(title)</dc:title>
            <dc:creator>\(author)</dc:creator>
            <dc:language>en</dc:language>
            <meta property=\"dcterms:modified\">\(modified)</meta>
          </metadata>
          <manifest>
            <item id=\"index\" href=\"index.xhtml\" media-type=\"application/xhtml+xml\" />
            <item id=\"style\" href=\"style.css\" media-type=\"text/css\" />
            <item id=\"nav\" href=\"nav.xhtml\" media-type=\"application/xhtml+xml\" properties=\"nav\" />\(imageManifest)
          </manifest>
          <spine>
            <itemref idref=\"index\" />
          </spine>
        </package>
        """
    }

        private func navDocument(title: String) -> String {
                let safeTitle = escape(title)
                return """
                <?xml version=\"1.0\" encoding=\"utf-8\"?>
                <!DOCTYPE html>
                <html xmlns=\"http://www.w3.org/1999/xhtml\" xmlns:epub=\"http://www.idpf.org/2007/ops\" xml:lang=\"en\">
                <head>
                    <title>Table of Contents</title>
                </head>
                <body>
                    <nav epub:type=\"toc\">
                        <ol>
                            <li><a href=\"index.xhtml\">\(safeTitle)</a></li>
                        </ol>
                    </nav>
                </body>
                </html>
                """
        }
    
    private func containerDocument() -> String {
        """
        <?xml version=\"1.0\" encoding=\"UTF-8\"?>
        <container version=\"1.0\" xmlns=\"urn:oasis:names:tc:opendocument:xmlns:container\">
            <rootfiles>
                <rootfile full-path=\"OEBPS/content.opf\" media-type=\"application/oebps-package+xml\" />
            </rootfiles>
        </container>
        """
    }
    
    private func stylesheet() -> String {
        """
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            font-size: 19px;
            line-height: 1.7;
            color: #000;
            background: #fff;
            margin: 0;
            padding: 24px 18px 48px;
        }
        h1, h2, h3, h4, h5, h6 {
            font-weight: 700;
            margin: 1.2em 0 0.4em;
            line-height: 1.25;
        }
        h1 { font-size: 1.8em; }
        h2 { font-size: 1.5em; }
        h3 { font-size: 1.3em; }
        p {
            margin: 0 0 1em 0;
        }
        img {
            max-width: 100%;
            height: auto;
            display: block;
            margin: 1.4em auto;
            border-radius: 8px;
        }
        figure { margin: 1.4em 0; }
        figcaption {
            text-align: center;
            font-size: 0.9em;
            color: #6b7280;
            margin-top: 0.4em;
            font-style: italic;
        }
        blockquote {
            border-left: 4px solid #d1d5db;
            padding-left: 1.2em;
            margin: 1.2em 0;
            font-style: italic;
            color: #374151;
            background: #f9fafb;
            padding: 1em 1.4em;
            border-radius: 4px;
        }
        a { color: #1d4ed8; text-decoration: none; }
        a:hover { text-decoration: underline; }
        ul, ol { margin: 1em 0; padding-left: 1.8em; }
        li { margin-bottom: 0.5em; }
        code {
            background: #f5f5f5;
            padding: 0.2em 0.4em;
            border-radius: 3px;
            font-size: 0.9em;
            font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
        }
        pre {
            background: #f5f5f5;
            padding: 1em;
            border-radius: 8px;
            overflow-x: auto;
            margin: 1.2em 0;
        }
        pre code { background: transparent; padding: 0; }
        table {
            width: 100%;
            border-collapse: collapse;
            margin: 1.2em 0;
        }
        th, td {
            border: 1px solid #e5e5e5;
            padding: 0.75em;
            text-align: left;
        }
        th { background: #f5f5f5; font-weight: 600; }
        .article-header { margin-bottom: 1.5em; }
        .article-header .eyebrow { font-size: 0.85em; text-transform: uppercase; letter-spacing: 0.08em; color: #2563eb; margin-bottom: 0.4em; }
        .article-header .meta { color: #6b7280; font-size: 0.95em; margin: 0 0 0.3em 0; }
        """
    }
    
    private func mimeType(for url: URL) -> String? {
        switch url.pathExtension.lowercased() {
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "gif": return "image/gif"
        case "webp": return "image/webp"
        case "svg": return "image/svg+xml"
        default: return nil
        }
    }
    
    private func normalizeVoidTags(_ html: String) -> String {
        var output = html
        
        // Remove invalid closing tags for void elements
        let voids = ["img", "br", "hr", "meta", "link", "source", "track", "input", "area", "base", "col", "embed", "param", "wbr"]
        for tag in voids {
            // Remove closing tags like </img>
            output = output.replacingOccurrences(of: "</\(tag)>", with: "", options: .caseInsensitive)
        }
        
        // Strip picture and source tags (keep content, especially img tags)
        if let pictureRegex = try? NSRegularExpression(pattern: "</?picture[^>]*>", options: [.caseInsensitive, .dotMatchesLineSeparators]) {
            output = pictureRegex.stringByReplacingMatches(in: output, options: [], range: NSRange(location: 0, length: output.utf16.count), withTemplate: "")
        }
        if let sourceRegex = try? NSRegularExpression(pattern: "<source[^>]*>", options: [.caseInsensitive, .dotMatchesLineSeparators]) {
            output = sourceRegex.stringByReplacingMatches(in: output, options: [], range: NSRange(location: 0, length: output.utf16.count), withTemplate: "")
        }
        
        // Ensure void tags are self-closing
        // Process each void element type
        for tag in voids {
            // Match opening tags that aren't already self-closed
            // Pattern: <tag + optional whitespace + any attributes + > (but not ending with /)
            var searchStart = output.startIndex
            while let tagStart = output.range(of: "<\(tag)", options: [.caseInsensitive], range: searchStart..<output.endIndex) {
                // Find the closing > for this tag
                guard let closePos = output[tagStart.upperBound...].firstIndex(of: ">") else {
                    break
                }
                
                // Check if it's already self-closing (ends with /)
                let beforeClose = output.index(before: closePos)
                if output[beforeClose] != "/" {
                    // Not self-closing, add the /
                    output.insert("/", at: closePos)
                    searchStart = output.index(after: closePos)
                } else {
                    searchStart = output.index(after: closePos)
                }
            }
        }
        
        return output
    }
    
    private func replaceHTMLEntities(_ html: String) -> String {
        var output = html
        
        // Replace common HTML entities with numeric character references
        // These are valid in XHTML without entity declarations
        let entityMap: [(String, String)] = [
            ("&nbsp;", "&#160;"),
            ("&ndash;", "&#8211;"),
            ("&mdash;", "&#8212;"),
            ("&hellip;", "&#8230;"),
            ("&ldquo;", "&#8220;"),
            ("&rdquo;", "&#8221;"),
            ("&lsquo;", "&#8216;"),
            ("&rsquo;", "&#8217;"),
            ("&bull;", "&#8226;"),
            ("&middot;", "&#183;"),
            ("&copy;", "&#169;"),
            ("&reg;", "&#174;"),
            ("&trade;", "&#8482;"),
            ("&deg;", "&#176;"),
            ("&plusmn;", "&#177;"),
            ("&para;", "&#182;"),
            ("&sect;", "&#167;"),
            ("&dagger;", "&#8224;"),
            ("&Dagger;", "&#8225;"),
            ("&euro;", "&#8364;"),
            ("&pound;", "&#163;"),
            ("&yen;", "&#165;"),
            ("&cent;", "&#162;"),
            ("&frac14;", "&#188;"),
            ("&frac12;", "&#189;"),
            ("&frac34;", "&#190;")
        ]
        
        for (entity, numeric) in entityMap {
            output = output.replacingOccurrences(of: entity, with: numeric)
        }
        
        return output
    }
    
    private func escape(_ value: String) -> String {
        var escaped = value
        let entities: [(String, String)] = [("&", "&amp;"), ("<", "&lt;"), (">", "&gt;"), ("\"", "&quot;"), ("'", "&apos;")]
        for (plain, entity) in entities {
            escaped = escaped.replacingOccurrences(of: plain, with: entity)
        }
        return escaped
    }
}

enum ExportError: Error {
    case archiveCreationFailed
}
