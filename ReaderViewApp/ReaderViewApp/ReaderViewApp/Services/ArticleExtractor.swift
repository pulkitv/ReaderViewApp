import WebKit
import Foundation

class ArticleExtractor {
    static let shared = ArticleExtractor()
    
    private init() {}
    
    func extractArticle(from url: URL, completion: @escaping (Result<Article, Error>) -> Void) {
        let webView = WKWebView()
        let delegate = ArticleExtractionNavigationDelegate(url: url, completion: completion)
        webView.navigationDelegate = delegate
        
        let request = URLRequest(url: url)
        webView.load(request)
        
        // Keep a strong reference to prevent deallocation
        ArticleExtractionContext.shared.activeExtractions[url] = (webView, delegate)
    }
}

// Context to hold active web views and delegates during extraction
class ArticleExtractionContext {
    static let shared = ArticleExtractionContext()
    var activeExtractions: [URL: (WKWebView, ArticleExtractionNavigationDelegate)] = [:]
    
    private init() {}
    
    func cleanup() {
        // Stop all loading and clear all active extractions
        for (_, (webView, _)) in activeExtractions {
            webView.stopLoading()
            webView.navigationDelegate = nil
        }
        activeExtractions.removeAll()
        print("🧹 Cleaned up all active extractions")
    }
    
    func cleanupExtraction(for url: URL) {
        if let (webView, _) = activeExtractions[url] {
            webView.stopLoading()
            webView.navigationDelegate = nil
            activeExtractions.removeValue(forKey: url)
            print("🧹 Cleaned up extraction for: \(url.absoluteString)")
        }
    }
}

class ArticleExtractionNavigationDelegate: NSObject, WKNavigationDelegate {
    let url: URL
    let completion: (Result<Article, Error>) -> Void
    
    init(url: URL, completion: @escaping (Result<Article, Error>) -> Void) {
        self.url = url
        self.completion = completion
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Extract content immediately after page loads
        self.extractContent(from: webView)
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        completion(.failure(error))
        ArticleExtractionContext.shared.cleanupExtraction(for: url)
    }
    
    private func extractContent(from webView: WKWebView) {
        let script = """
        (function() {
            // Inline Readability.js code
            \(readabilityJS)
            
            try {
                const documentClone = document.cloneNode(true);
                const reader = new Readability(documentClone);
                const article = reader.parse();
                
                if (!article) {
                    return JSON.stringify({ error: 'Could not parse article' });
                }
                
                return JSON.stringify({
                    title: article.title,
                    byline: article.byline,
                    content: article.content,
                    textContent: article.textContent,
                    length: article.length,
                    excerpt: article.excerpt,
                    siteName: article.siteName
                });
            } catch (error) {
                return JSON.stringify({ error: error.message });
            }
        })();
        """
        
        webView.evaluateJavaScript(script) { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                self.completion(.failure(error))
                ArticleExtractionContext.shared.cleanupExtraction(for: self.url)
                return
            }
            
            guard let jsonString = result as? String,
                  let data = jsonString.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                self.completion(.failure(NSError(domain: "ArticleExtractor", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse result"])))
                ArticleExtractionContext.shared.cleanupExtraction(for: self.url)
                return
            }
            
            if let errorMessage = json["error"] as? String {
                self.completion(.failure(NSError(domain: "ArticleExtractor", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage])))
                ArticleExtractionContext.shared.cleanupExtraction(for: self.url)
                return
            }
            
            let article = Article(
                title: json["title"] as? String ?? "Untitled",
                byline: json["byline"] as? String,
                content: json["content"] as? String ?? "",
                textContent: json["textContent"] as? String ?? "",
                length: json["length"] as? Int ?? 0,
                excerpt: json["excerpt"] as? String,
                siteName: json["siteName"] as? String,
                url: self.url.absoluteString
            )
            
            self.completion(.success(article))
            ArticleExtractionContext.shared.cleanupExtraction(for: self.url)
        }
    }
    
    // Readability.js content will be loaded from a file
    private var readabilityJS: String {
        guard let path = Bundle.main.path(forResource: "Readability", ofType: "js"),
              let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            return ""
        }
        return content
    }
}

enum ArticleExtractionError: Error, LocalizedError {
    case invalidURL
    case parsingFailed
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .parsingFailed:
            return "Could not extract article content"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
