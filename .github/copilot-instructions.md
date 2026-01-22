# ReaderViewApp - AI Coding Instructions

## Architecture Overview

This is a **native iOS SwiftUI app** that extracts article content using **client-side JavaScript injection**. The app leverages Mozilla's Readability.js library loaded into WKWebView to parse DOM and extract clean article content without requiring a backend server.

### Core Components

1. **ArticleExtractor** (singleton): Manages WKWebView lifecycle for article extraction
   - Creates temporary WKWebView instances per extraction request
   - Injects Readability.js after page load (with 1s delay for dynamic content)
   - Parses JSON result back to Swift and creates Article objects
   - Uses `ArticleExtractionContext.shared.activeExtractions` dictionary to maintain strong references during extraction

2. **ArticleStore** (ObservableObject): Centralized state management
   - `@Published var currentArticle: Article?` - drives main UI rendering
   - `@Published var savedArticles: [Article]` - future persistence feature
   - Shared via `@EnvironmentObject` across views

3. **Share Extension**: iOS system integration for share sheet
   - Handles URL/text sharing from any app (Safari, Chrome, etc.)
   - Constructs custom URL scheme: `readerviewapp://share?url={encoded_url}`
   - Uses responder chain to open main app via `UIApplication.open()`

4. **URL Scheme Handler**: Bridge between ShareExtension and main app
   - Add `.onOpenURL` handler in ReaderViewApp.swift (currently missing - see README Step 6)
   - Parse `url` query parameter and trigger ArticleExtractor

## Critical Developer Workflows

### Initial Setup
```bash
# Download Readability.js into project
cd ReaderViewApp/ReaderViewApp
curl -o Readability.js https://raw.githubusercontent.com/mozilla/readability/main/Readability.js
```

**Important**: Readability.js MUST be added to Xcode project target "ReaderViewApp" (not ShareExtension) since ArticleExtractor loads it via `Bundle.main.path(forResource: "Readability", ofType: "js")`

### Building & Running
- Build: Cmd+B (ensure both ReaderViewApp and ShareExtension targets compile)
- Run: Cmd+R (deploys main app + extension to device/simulator)
- Test Share Extension: Share a URL from Safari → Select "Reader View" from share sheet

### Debugging Extraction Issues
- Check Console for JavaScript evaluation errors in `webView.evaluateJavaScript()`
- Verify Readability.js is in bundle: `Bundle.main.path(forResource: "Readability", ofType: "js")`
- Increase delay in `ArticleExtractionNavigationDelegate.webView(_:didFinish:)` if content loads slowly

## Project-Specific Patterns

### State Management Convention
- Use `@EnvironmentObject` for shared state (ArticleStore)
- All article mutations happen through ArticleStore methods
- Clear article with `articleStore.clearCurrentArticle()` to return to empty state

### Navigation Pattern
- Single NavigationView in ContentView with conditional rendering:
  - `if let article = articleStore.currentArticle` → shows ReaderView
  - `else` → shows EmptyStateView
- No NavigationLink navigation; state changes drive view transitions

### Memory Management for WKWebView
**Critical Pattern**: WKWebView instances are deallocated after creation unless retained
- `ArticleExtractionContext.shared.activeExtractions[url] = webView` maintains strong reference during extraction
- Remove reference after completion/error: `ArticleExtractionContext.shared.activeExtractions.removeValue(forKey: url)`

### JavaScript Integration
Readability.js is **inlined** into JavaScript string, not loaded via `WKUserScript`:
```swift
let script = """
(function() {
    \(readabilityJS)  // Entire Readability.js content injected here
    const reader = new Readability(document.cloneNode(true));
    return JSON.stringify(reader.parse());
})();
"""
```

## Configuration Requirements

### URL Scheme Setup (Required)
1. Main app target → Info tab → URL Types
2. Add: Identifier: `com.yourname.readerviewapp`, URL Schemes: `readerviewapp`
3. Implement `.onOpenURL` handler in ReaderViewApp.swift (see README.md Step 6)

### App Groups (Optional - for future persistence)
- Capability: App Groups with `group.com.yourname.readerviewapp`
- Add to both ReaderViewApp and ShareExtension targets
- Enables shared UserDefaults/file storage between app and extension

## Key Files Reference

- [ReaderViewApp/Services/ArticleExtractor.swift](ReaderViewApp/Services/ArticleExtractor.swift) - Core extraction logic with WKWebView lifecycle
- [ReaderViewApp/Models/Article.swift](ReaderViewApp/Models/Article.swift) - Data model and ArticleStore singleton
- [ShareExtension/ShareViewController.swift](ShareExtension/ShareViewController.swift) - Share sheet integration with URL scheme handling
- [ReaderViewApp/ContentView.swift](ReaderViewApp/ContentView.swift) - State-driven navigation and manual URL input

## Common Modifications

**Adding new Article fields**: Update Article struct + JavaScript JSON serialization in ArticleExtractor
**Changing extraction delay**: Modify `DispatchQueue.main.asyncAfter(deadline: .now() + 1.0)` in ArticleExtractionNavigationDelegate
**Custom styling**: HTML content in ReaderView uses inline CSS - modify ArticleContentView wrapper
