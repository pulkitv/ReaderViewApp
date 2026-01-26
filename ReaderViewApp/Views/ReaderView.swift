import SwiftUI
import WebKit

struct ReaderView: View {
    let article: Article
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var articleStore: ArticleStore
    @State private var contentHeight: CGFloat = 500
    @State private var isExportingEPUB = false
    @State private var epubURL: URL?
    @State private var showEPUBShareSheet = false
    @State private var exportError: String?
    private let epubExporter = EpubExporter()
    
    var estimatedReadingTime: Int {
        article.length / 200
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header with metadata
                VStack(alignment: .leading, spacing: 12) {
                    if let siteName = article.siteName {
                        Text(siteName)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    }
                    
                    Text(article.title)
                        .font(.system(.title, design: .serif))
                        .fontWeight(.bold)
                    
                    HStack(spacing: 16) {
                        if let byline = article.byline {
                            Label(byline, systemImage: "person.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Label("\(estimatedReadingTime) min read", systemImage: "clock")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Label("\(article.length) words", systemImage: "text.alignleft")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.bottom, 8)
                
                Divider()
                
                // Article content using WKWebView for HTML rendering
                ArticleContentView(htmlContent: article.content, baseURL: URL(string: article.url), contentHeight: $contentHeight)
                    .frame(height: contentHeight)
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    articleStore.clearCurrentArticle()
                }) {
                    Image(systemName: "xmark")
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: {
                        shareArticle()
                    }) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }

                    Button(action: {
                        exportEPUB()
                    }) {
                        Label("Export EPUB", systemImage: "book")
                    }
                    
                    Button(action: {
                        articleStore.saveArticle(article)
                    }) {
                        Label("Save for Later", systemImage: "bookmark")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .overlay(alignment: .center) {
            if isExportingEPUB {
                VStack(spacing: 12) {
                    ProgressView("Preparing EPUB…")
                    Text("This may take a moment for image-heavy articles.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .padding(16)
                .background(.regularMaterial)
                .cornerRadius(12)
            }
        }
        .sheet(isPresented: $showEPUBShareSheet, onDismiss: {
            if let epubURL {
                try? FileManager.default.removeItem(at: epubURL)
            }
            epubURL = nil
        }) {
            if let epubURL {
                ActivityView(activityItems: [epubURL])
            }
        }
        .alert("EPUB export failed", isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })) {
            Button("OK", role: .cancel) { exportError = nil }
        } message: {
            Text(exportError ?? "Unknown error")
        }
    }
    
    private func shareArticle() {
        guard let url = URL(string: article.url) else { return }
        
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityVC, animated: true)
        }
    }

    private func exportEPUB() {
        guard !isExportingEPUB else { return }
        isExportingEPUB = true
        epubURL = nil
        exportError = nil
        Task {
            do {
                let url = try await epubExporter.export(article: article)
                await MainActor.run {
                    epubURL = url
                    isExportingEPUB = false
                    showEPUBShareSheet = true
                }
            } catch {
                await MainActor.run {
                    isExportingEPUB = false
                    exportError = error.localizedDescription
                }
            }
        }
    }
}

struct ArticleContentView: UIViewRepresentable {
    let htmlContent: String
    let baseURL: URL?
    @Binding var contentHeight: CGFloat
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        
        // Enable preferences for loading remote content
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences = preferences
        
        // Enable media types
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.scrollView.isScrollEnabled = false
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .clear
        
        // Store weak reference for cleanup
        context.coordinator.webView = webView
        
        // Observe content size changes
        webView.scrollView.addObserver(context.coordinator, forKeyPath: "contentSize", options: .new, context: nil)
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.heightBinding = $contentHeight
        let styledHTML = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
                    font-size: 19px;
                    line-height: 1.7;
                    color: #000000;
                    background-color: #ffffff;
                    padding: 0;
                    margin: 0;
                    font-weight: 400;
                    -webkit-font-smoothing: antialiased;
                    -moz-osx-font-smoothing: grayscale;
                }
                
                @media (prefers-color-scheme: dark) {
                    body {
                        color: #ffffff;
                        background-color: #000000;
                    }
                    a {
                        color: #60a5fa;
                    }
                    img {
                        opacity: 0.9;
                    }
                    blockquote {
                        border-left-color: #555;
                        color: #ccc;
                    }
                    code {
                        background-color: #1a1a1a;
                    }
                    pre {
                        background-color: #1a1a1a;
                    }
                    th, td {
                        border-color: #444;
                    }
                    th {
                        background-color: #1a1a1a;
                    }
                }
                
                p {
                    margin-bottom: 1.3em;
                    color: inherit;
                }
                
                h1, h2, h3, h4, h5, h6 {
                    font-weight: 700;
                    margin-top: 1.8em;
                    margin-bottom: 0.6em;
                    line-height: 1.3;
                    color: inherit;
                }
                
                h1 { font-size: 2em; }
                h2 { font-size: 1.75em; }
                h3 { font-size: 1.5em; }
                
                img {
                    max-width: 100%;
                    height: auto;
                    display: block;
                    margin: 1.5em auto;
                    border-radius: 8px;
                }
                
                figure {
                    margin: 1.5em 0;
                }
                
                figcaption {
                    text-align: center;
                    font-size: 0.875em;
                    color: #6b7280;
                    margin-top: 0.5em;
                    font-style: italic;
                }
                
                blockquote {
                    border-left: 4px solid #d1d5db;
                    padding-left: 1.5em;
                    margin: 1.5em 0;
                    font-style: italic;
                    color: #374151;
                    background-color: #f9fafb;
                    padding: 1em 1.5em;
                    border-radius: 4px;
                }
                
                a {
                    color: #1d4ed8;
                    text-decoration: none;
                    font-weight: 500;
                }
                
                a:hover {
                    text-decoration: underline;
                    color: #1e40af;
                }
                
                ul, ol {
                    margin: 1em 0;
                    padding-left: 2em;
                }
                
                li {
                    margin-bottom: 0.5em;
                }
                
                code {
                    background-color: #f5f5f5;
                    padding: 0.2em 0.4em;
                    border-radius: 3px;
                    font-size: 0.9em;
                    font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
                }
                
                @media (prefers-color-scheme: dark) {
                    code {
                        background-color: #2a2a2a;
                    }
                }
                
                pre {
                    background-color: #f5f5f5;
                    padding: 1em;
                    border-radius: 8px;
                    overflow-x: auto;
                    margin: 1.5em 0;
                }
                
                @media (prefers-color-scheme: dark) {
                    pre {
                        background-color: #2a2a2a;
                    }
                }
                
                pre code {
                    background-color: transparent;
                    padding: 0;
                }
                
                table {
                    width: 100%;
                    border-collapse: collapse;
                    margin: 1.5em 0;
                }
                
                th, td {
                    border: 1px solid #e5e5e5;
                    padding: 0.75em;
                    text-align: left;
                }
                
                th {
                    background-color: #f5f5f5;
                    font-weight: 600;
                }
                
                @media (prefers-color-scheme: dark) {
                    th, td {
                        border-color: #333;
                    }
                    th {
                        background-color: #2a2a2a;
                    }
                }
            </style>
        </head>
        <body>
            \(htmlContent)
        </body>
        </html>
        """
        
        if let data = styledHTML.data(using: .utf8) {
            webView.load(data, mimeType: "text/html", characterEncodingName: "utf-8", baseURL: baseURL ?? URL(string: "about:blank")!)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var heightBinding: Binding<CGFloat>?
        weak var webView: WKWebView?
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // Open links in Safari
            if navigationAction.navigationType == .linkActivated {
                if let url = navigationAction.request.url {
                    UIApplication.shared.open(url)
                    decisionHandler(.cancel)
                    return
                }
            }
            decisionHandler(.allow)
        }
        
        override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
            if keyPath == "contentSize" {
                if let scrollView = object as? UIScrollView {
                    DispatchQueue.main.async {
                        self.heightBinding?.wrappedValue = scrollView.contentSize.height
                    }
                }
            }
        }
        
        deinit {
            // Clean up observer
            webView?.scrollView.removeObserver(self, forKeyPath: "contentSize")
        }
    }
}

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No updates needed
    }
}
