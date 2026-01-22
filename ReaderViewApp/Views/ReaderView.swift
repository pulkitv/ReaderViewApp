import SwiftUI
import WebKit

struct ReaderView: View {
    let article: Article
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var articleStore: ArticleStore
    
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
                ArticleContentView(htmlContent: article.content)
                    .frame(minHeight: 500)
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
                        articleStore.saveArticle(article)
                    }) {
                        Label("Save for Later", systemImage: "bookmark")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
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
}

struct ArticleContentView: UIViewRepresentable {
    let htmlContent: String
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.scrollView.isScrollEnabled = false
        webView.navigationDelegate = context.coordinator
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        let styledHTML = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
                    font-size: 18px;
                    line-height: 1.6;
                    color: #1a1a1a;
                    padding: 0;
                    margin: 0;
                }
                
                @media (prefers-color-scheme: dark) {
                    body {
                        color: #e5e5e5;
                        background: transparent;
                    }
                    a {
                        color: #60a5fa;
                    }
                    img {
                        opacity: 0.9;
                    }
                }
                
                p {
                    margin-bottom: 1.2em;
                }
                
                h1, h2, h3, h4, h5, h6 {
                    font-weight: 700;
                    margin-top: 1.5em;
                    margin-bottom: 0.5em;
                    line-height: 1.3;
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
                    color: #666;
                    margin-top: 0.5em;
                    font-style: italic;
                }
                
                blockquote {
                    border-left: 4px solid #e5e5e5;
                    padding-left: 1.5em;
                    margin: 1.5em 0;
                    font-style: italic;
                    color: #555;
                }
                
                @media (prefers-color-scheme: dark) {
                    blockquote {
                        border-left-color: #444;
                        color: #aaa;
                    }
                }
                
                a {
                    color: #2563eb;
                    text-decoration: none;
                }
                
                a:hover {
                    text-decoration: underline;
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
        
        webView.loadHTMLString(styledHTML, baseURL: nil)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
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
    }
}
