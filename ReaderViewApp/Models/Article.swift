import Foundation
import Combine

class ArticleStore: ObservableObject {
    @Published var currentArticle: Article?
    @Published var savedArticles: [Article] = []
    
    func saveArticle(_ article: Article) {
        savedArticles.append(article)
    }
    
    func clearCurrentArticle() {
        currentArticle = nil
    }
}

struct Article: Identifiable, Codable {
    let id: UUID
    let title: String
    let byline: String?
    let content: String
    let textContent: String
    let length: Int
    let excerpt: String?
    let siteName: String?
    let url: String
    let dateExtracted: Date
    
    init(id: UUID = UUID(), title: String, byline: String?, content: String, textContent: String, length: Int, excerpt: String?, siteName: String?, url: String, dateExtracted: Date = Date()) {
        self.id = id
        self.title = title
        self.byline = byline
        self.content = content
        self.textContent = textContent
        self.length = length
        self.excerpt = excerpt
        self.siteName = siteName
        self.url = url
        self.dateExtracted = dateExtracted
    }
}
