//
//  ReaderViewAppApp.swift
//  ReaderViewApp
//
//  Created by Pulkit Vashishta on 22/01/26.
//

import SwiftUI

@main
struct ReaderViewAppApp: App {
    @StateObject private var articleStore = ArticleStore()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(articleStore)
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
        }
    }
    
    private func handleIncomingURL(_ url: URL) {
        print("📱 Received URL: \(url.absoluteString)")
        print("📱 Scheme: \(url.scheme ?? "nil")")
        print("📱 Host: \(url.host ?? "nil")")
        
        guard url.scheme == "readerviewapp",
              url.host == "share",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let urlString = components.queryItems?.first(where: { $0.name == "url" })?.value,
              let articleURL = URL(string: urlString) else {
            print("❌ Failed to parse URL scheme")
            return
        }
        
        print("✅ Extracting article from: \(articleURL.absoluteString)")
        
        ArticleExtractor.shared.extractArticle(from: articleURL) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let article):
                    print("✅ Article extracted: \(article.title)")
                    self.articleStore.currentArticle = article
                case .failure(let error):
                    print("❌ Extraction error: \(error)")
                }
            }
        }
    }
}
