import SwiftUI

@main
struct ReaderViewApp: App {
    @StateObject private var articleStore = ArticleStore()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(articleStore)
        }
    }
}
