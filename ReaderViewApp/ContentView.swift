import SwiftUI

struct ContentView: View {
    @EnvironmentObject var articleStore: ArticleStore
    @State private var showingManualInput = false
    @State private var manualURL = ""
    
    var body: some View {
        NavigationView {
            Group {
                if let article = articleStore.currentArticle {
                    ReaderView(article: article)
                } else {
                    EmptyStateView(showingManualInput: $showingManualInput, manualURL: $manualURL)
                }
            }
            .navigationTitle("Reader View")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showingManualInput) {
            ManualURLInputView(url: $manualURL, isPresented: $showingManualInput)
        }
    }
}

struct EmptyStateView: View {
    @Binding var showingManualInput: Bool
    @Binding var manualURL: String
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "book.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            VStack(spacing: 12) {
                Text("Welcome to Reader View")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Share any article from Safari, Chrome, or any app to read it here in a clean, distraction-free format.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
            
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title2)
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Share from any app")
                            .font(.headline)
                        Text("Tap the share button and select Reader View")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
                
                Button(action: {
                    showingManualInput = true
                }) {
                    HStack {
                        Image(systemName: "link")
                        Text("Or paste a URL manually")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal)
        }
        .padding()
    }
}

struct ManualURLInputView: View {
    @Binding var url: String
    @Binding var isPresented: Bool
    @EnvironmentObject var articleStore: ArticleStore
    @State private var isLoading = false
    @State private var error: String?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                TextField("Enter article URL", text: $url)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .padding()
                
                if let error = error {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.horizontal)
                }
                
                Button(action: extractArticle) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Extract Article")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(url.isEmpty ? Color.gray : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
                .padding(.horizontal)
                .disabled(url.isEmpty || isLoading)
                
                Spacer()
            }
            .navigationTitle("Paste URL")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
    
    private func extractArticle() {
        guard let validURL = URL(string: url) else {
            error = "Invalid URL"
            return
        }
        
        isLoading = true
        error = nil
        
        ArticleExtractor.shared.extractArticle(from: validURL) { result in
            DispatchQueue.main.async {
                isLoading = false
                
                switch result {
                case .success(let article):
                    articleStore.currentArticle = article
                    isPresented = false
                case .failure(let extractionError):
                    error = extractionError.localizedDescription
                }
            }
        }
    }
}
