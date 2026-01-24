import SwiftUI

@main
struct ReaderViewApp: App {
    @StateObject private var articleStore = ArticleStore()
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(articleStore)
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
        }
        .onChange(of: scenePhase) {
            handleScenePhaseChange()
        }
    }
    
    private func handleScenePhaseChange() {
        switch scenePhase {
        case .background:
            print("📱 App entered background - cleaning up extractions")
            ArticleExtractionContext.shared.cleanup()
        case .active:
            print("📱 App became active")
        case .inactive:
            print("📱 App became inactive")
        @unknown default:
            break
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
        
        // Note: Loading state is managed in ContentView via onChange
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
