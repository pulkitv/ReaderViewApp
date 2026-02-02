# ReaderViewApp - Technical Documentation

**Last Updated:** February 2, 2026  
**Version:** 2.0  
**Platform:** iOS 16.0+  
**Language:** Swift 5.9+ (SwiftUI)

---

## Table of Contents

1. [Project Overview](#project-overview)
2. [Architecture](#architecture)
3. [Key Components](#key-components)
4. [State Management](#state-management)
5. [Feature Timeline](#feature-timeline)
6. [Code Patterns & Conventions](#code-patterns--conventions)
7. [External Dependencies](#external-dependencies)
8. [API Reference](#api-reference)
9. [Common Tasks](#common-tasks)
10. [Known Limitations](#known-limitations)

---

## Project Overview

### Purpose
ReaderViewApp is a native iOS application that provides distraction-free article reading by extracting clean content from web pages. It combines iOS share extension capabilities with Mozilla's Readability.js library to offer a seamless reading experience with EPUB export functionality.

### Core Philosophy
- **Privacy-first**: All extraction happens on-device using client-side JavaScript
- **Native Experience**: SwiftUI-based UI with native iOS patterns
- **Universal Compatibility**: Works with any website accessible in a browser
- **Offline-capable**: EPUB export enables permanent offline access

### Target Audience
- Users who want distraction-free reading across apps
- People who need offline article access
- iOS users who prefer native apps over web services

---

## Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    iOS System                           │
│  ┌──────────────┐         ┌─────────────────────┐      │
│  │ Safari/Apps  │─share──→│  Share Extension    │      │
│  └──────────────┘         └─────────────────────┘      │
│                                    │                     │
│                                    ▼                     │
│                          readerviewapp://share?url=...  │
│                                    │                     │
│  ┌────────────────────────────────▼──────────────────┐  │
│  │           Main App (ReaderViewApp)                │  │
│  │  ┌──────────────────────────────────────────┐    │  │
│  │  │        ArticleStore (State)              │    │  │
│  │  │  @Published currentArticle: Article?     │    │  │
│  │  └──────────────────────────────────────────┘    │  │
│  │           │                    │                  │  │
│  │           ▼                    ▼                  │  │
│  │  ┌────────────────┐   ┌────────────────┐         │  │
│  │  │ ContentView    │   │  ReaderView    │         │  │
│  │  │ (Empty State)  │   │  (Article UI)  │         │  │
│  │  └────────────────┘   └────────────────┘         │  │
│  │           │                    │                  │  │
│  │           ▼                    ▼                  │  │
│  │  ┌────────────────────────────────────────────┐  │  │
│  │  │      ArticleExtractor (Singleton)          │  │  │
│  │  │  - Manages WKWebView lifecycle             │  │  │
│  │  │  - Injects Readability.js                  │  │  │
│  │  │  - Extracts article data                   │  │  │
│  │  └────────────────────────────────────────────┘  │  │
│  │           │                    │                  │  │
│  │           ▼                    ▼                  │  │
│  │  ┌────────────────┐   ┌────────────────┐         │  │
│  │  │ WKWebView      │   │ EpubExporter   │         │  │
│  │  │ (Extraction)   │   │ (EPUB Export)  │         │  │
│  │  └────────────────┘   └────────────────┘         │  │
│  └─────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

### Data Flow

1. **URL Ingestion**
   ```
   Safari/App → Share Button → ShareExtension → URL Scheme → Main App
   ```

2. **Article Extraction**
   ```
   URL → ArticleExtractor → WKWebView.load(url) → 
   Page Load → Inject Readability.js → Parse DOM → 
   Extract JSON → Swift Decode → Article Object → ArticleStore
   ```

3. **Rendering**
   ```
   ArticleStore.currentArticle → ReaderView → 
   WKWebView.load(styledHTML, baseURL) → Display with CSS
   ```

4. **EPUB Export**
   ```
   Article → EpubExporter → Download Images → 
   Transcode WebP/SVG → Build XHTML → Package ZIP → 
   Save .epub → Share Sheet
   ```

---

## Key Components

### 1. ArticleStore (`Models/Article.swift`)

**Purpose:** Centralized state management using Combine framework

```swift
class ArticleStore: ObservableObject {
    @Published var currentArticle: Article?
    @Published var savedArticles: [Article] = []
}
```

**Responsibilities:**
- Holds currently displayed article
- Manages saved articles list (future feature)
- Notifies UI of state changes via `@Published`

**Access Pattern:** Injected via `@EnvironmentObject` in SwiftUI views

---

### 2. Article (`Models/Article.swift`)

**Purpose:** Immutable data model for extracted articles

```swift
struct Article: Identifiable, Codable, Equatable {
    let id: UUID
    let title: String
    let byline: String?          // Author name
    let content: String          // HTML content
    let textContent: String      // Plain text version
    let length: Int              // Word count
    let excerpt: String?         // Short summary
    let siteName: String?        // Source website
    let url: String              // Original URL
    let dateExtracted: Date      // Extraction timestamp
}
```

**Key Fields:**
- `content`: Full HTML with images, used for rendering
- `textContent`: Stripped text for search/analysis
- `url`: Preserved for baseURL resolution in WKWebView
- `dateExtracted`: Used in EPUB metadata

---

### 3. ArticleExtractor (`Services/ArticleExtractor.swift`)

**Purpose:** Singleton service managing article extraction lifecycle

**Critical Pattern - WKWebView Memory Management:**
```swift
class ArticleExtractionContext {
    static let shared = ArticleExtractionContext()
    var activeExtractions: [String: WKWebView] = [:]
}
```

**Why This Exists:**  
WKWebView instances are deallocated immediately after creation unless retained. The context maintains strong references during extraction, then releases them on completion.

**Extraction Flow:**
1. Create WKWebView with navigation delegate
2. Store in `activeExtractions[url]`
3. Load URL
4. On `didFinish`: Wait 1s (for dynamic content), inject Readability.js
5. Evaluate JS and parse JSON result
6. Create Article object
7. Remove from `activeExtractions`

**JavaScript Injection:**
```swift
let script = """
(function() {
    \(readabilityJS)  // Inline entire Readability.js
    const reader = new Readability(document.cloneNode(true));
    return JSON.stringify(reader.parse());
})();
"""
webView.evaluateJavaScript(script) { result, error in ... }
```

---

### 4. ReaderView (`Views/ReaderView.swift`)

**Purpose:** Displays extracted article with styled content and EPUB export

**Key State Variables:**
```swift
@State private var contentHeight: CGFloat = 500
@State private var isExportingEPUB = false
@State private var epubURL: URL?
@State private var showEPUBShareSheet = false
@State private var exportError: String?
```

**ArticleContentView (Nested):**
- Uses `UIViewRepresentable` to wrap WKWebView
- **Critical Fix (Jan 25, 2026):** Uses `baseURL` parameter to resolve relative image URLs
- Observes `contentSize` to dynamically adjust frame height
- Opens links in Safari via `decidePolicyFor navigationAction`

**WKWebView Configuration:**
```swift
let configuration = WKWebViewConfiguration()
configuration.allowsInlineMediaPlayback = true
let preferences = WKWebpagePreferences()
preferences.allowsContentJavaScript = true
configuration.defaultWebpagePreferences = preferences
```

**Rendering Method (Jan 25, 2026):**
```swift
webView.load(data, mimeType: "text/html", 
             characterEncodingName: "utf-8", 
             baseURL: URL(string: article.url))
```
Changed from `loadHTMLString` to `load(_:mimeType:...)` for better external resource loading.

---

### 5. EpubExporter (`Services/EpubExporter.swift`)

**Purpose:** Generates EPUB 3.0 packages with embedded images

**Dependencies:**
- ZIPFoundation (SPM): EPUB packaging
- UIKit: Image transcoding
- WebKit: SVG rasterization

**Key Data Structure:**
```swift
struct ImageResource {
    let filename: String    // e.g., "image1.jpg"
    let data: Data
    let mimeType: String    // e.g., "image/jpeg"
}
```

**Export Pipeline:**
1. **Image Extraction & Transcoding**
   - Regex match all `<img src="...">` in HTML
   - Download images via URLSession
   - Detect WebP/SVG formats
   - **WebP → JPEG/PNG:** `UIImage(data:)` decode + JPEG export
   - **SVG → PNG:** WKWebView snapshot (1024×768px canvas)
   - Store as `ImageResource` with local path `images/imageN.ext`
   - Replace `src` attributes with local paths

2. **XHTML Generation**
   - Escape title/author for XML safety
   - Strip responsive img attributes (`srcset`, `sizes`, `loading`, `data-*`)
   - Normalize void tags (`<img>` → `<img />`)
   - Replace HTML entities (`&nbsp;` → `&#160;`)
   - Wrap in XHTML with nav header

3. **EPUB Structure**
   ```
   mimetype                        (uncompressed, must be first)
   META-INF/container.xml
   OEBPS/
   ├── content.opf                 (manifest + spine)
   ├── nav.xhtml                   (table of contents)
   ├── index.xhtml                 (article content)
   ├── style.css                   (reader styles)
   └── images/
       ├── image1.jpg
       ├── image2.png
       └── ...
   ```

4. **ZIP Packaging**
   - ZIPFoundation with `accessMode: .create`
   - `mimetype` added first with `.none` compression
   - All other files with `.deflate` compression
   - Uses Int64 sizes for API compatibility

**Critical Fixes (Jan 25-26, 2026):**
- Strip `srcset`/`sizes` to ensure `src` is used (Apple Books compatibility)
- Convert named entities to numeric (`&nbsp;` → `&#160;`) for XHTML parsers
- Add `xmlns:epub` namespace to nav.xhtml for `epub:type` attribute
- Transcode WebP/SVG to JPEG/PNG for universal reader support

---

### 6. ShareExtension (`ShareExtension/ShareViewController.swift`)

**Purpose:** iOS system extension for sharing URLs from other apps

**Activation Rule (Info.plist):**
```xml
<key>NSExtensionActivationRule</key>
<dict>
    <key>NSExtensionActivationSupportsWebURLWithMaxCount</key>
    <integer>1</integer>
</dict>
```

**URL Scheme Handoff:**
```swift
let urlScheme = "readerviewapp://share?url=\(encodedURL)"
UIApplication.shared.open(URL(string: urlScheme)!)
```

**Sequence:**
1. User taps share button in Safari/app
2. ShareViewController receives URL via extensionContext
3. Constructs custom URL scheme with encoded URL
4. Opens main app via `UIApplication.shared.open()`
5. Dismisses share sheet immediately

---

## State Management

### ArticleStore as Source of Truth

**Pattern:** Single source of truth with Combine publishers

```swift
// App Entry Point
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
```

**State Transitions:**

```
Empty State (currentArticle = nil)
    ↓ URL received via share or manual input
    ↓ ArticleExtractor.extractArticle()
    ↓
Extracting (loading indicator)
    ↓ Success
    ↓
Article Displayed (currentArticle = Article)
    ↓ User taps close
    ↓ articleStore.clearCurrentArticle()
    ↓
Empty State
```

**Navigation Pattern:**
- No NavigationLink - state-driven conditional rendering
- `if let article = articleStore.currentArticle` → ReaderView
- `else` → ContentView (empty state)

---

## Feature Timeline

### Phase 1: Core Functionality (Initial Release, January 2026)

**Date:** ~January 15-20, 2026

**Features Implemented:**
- ✅ Basic article extraction with Readability.js
- ✅ Share extension integration
- ✅ SwiftUI reader view
- ✅ Manual URL input
- ✅ Dark mode support
- ✅ Article metadata display (author, word count, reading time)

**Key Commits:**
- Initial project setup
- ArticleExtractor with WKWebView lifecycle management
- Share extension with URL scheme handoff

---

### Phase 2: UI & UX Improvements (January 25, 2026)

**Date:** January 25, 2026

**Features Implemented:**
- ✅ Fixed scrolling in ReaderView (removed fixed height)
- ✅ Enhanced typography and spacing
- ✅ Performance optimization (removed artificial delays)
- ✅ Loading overlays for extraction feedback
- ✅ Fixed deprecated `onChange` modifier
- ✅ Article Equatable conformance for efficient re-renders
- ✅ Share extension sequencing improvements
- ✅ WKWebView cleanup and memory management

**Problems Solved:**
- Scrolling issues with fixed WebView height
- Poor UX during extraction (no feedback)
- Deprecated API warnings
- Memory leaks in WKWebView lifecycle

**Commit:** "Fix scrolling, styling, performance; add loading overlays; deprecated onChange fix; Article Equatable; WKWebView cleanup; share extension tweaks"

---

### Phase 3: EPUB Export Foundation (January 25, 2026)

**Date:** January 25, 2026

**Features Implemented:**
- ✅ ZIPFoundation dependency via Swift Package Manager
- ✅ EpubExporter service with EPUB 3.0 structure
- ✅ Image extraction and base64 inline embedding (initial approach)
- ✅ Export UI in ReaderView (menu action, progress overlay, share sheet)
- ✅ Temporary file cleanup after share dismissal
- ✅ Navigation table of contents (nav.xhtml)

**Technical Decisions:**
- Initial approach: Base64 data URIs for images (later changed)
- EPUB structure: mimetype + META-INF + OEBPS
- SPM for dependency management

**Commit:** "Add EPUB export with ZIPFoundation; inline images; wire export UI"

---

### Phase 4: EPUB Robustness & Apple Books Compatibility (January 25-26, 2026)

**Dates:** January 25-26, 2026

**Features Implemented:**
- ✅ Relative image URL resolution with baseURL
- ✅ Network timeouts for image downloads (12s)
- ✅ Image size cap (8MB) to prevent memory issues
- ✅ Void tag normalization (`<img>` → `<img />`)
- ✅ Temporary file cleanup on share sheet dismissal
- ✅ ZIPFoundation API deprecation fixes (Archive init, CompressionMethod, addEntry signature)

**Problems Solved:**
- Images not loading due to relative URLs
- EPUB validator errors for unclosed void tags
- Deprecated API warnings
- Memory spikes from large images

**Commits:**
- "Add nav.xhtml, relative image resolution, timeout, void-tag normalization"
- "Resolve deprecations: Archive initializer, CompressionMethod, addEntry signature"

---

### Phase 5: Image Display Fixes & WKWebView Configuration (January 26, 2026)

**Date:** January 26, 2026

**Features Implemented:**
- ✅ WKWebView baseURL support for relative image paths
- ✅ Changed from `loadHTMLString` to `load(_:mimeType:characterEncodingName:baseURL:)`
- ✅ WKWebViewConfiguration with inline media playback
- ✅ JavaScript enabled for reader view
- ✅ Transparent WebView background

**Problems Solved:**
- Images not displaying in reader view (WKWebView couldn't resolve relative URLs)
- External resources blocked by default WKWebView config

**Commit:** "ReaderView: use baseURL + load(data:), enable JS and media"

---

### Phase 6: EPUB Images as Files & XHTML Compliance (January 26, 2026)

**Date:** January 26, 2026

**Features Implemented:**
- ✅ **Images stored as separate files** in EPUB (not data URIs)
- ✅ Image manifest entries in content.opf
- ✅ Strip `<picture>` and `<source>` tags (keep `<img>`)
- ✅ Remove responsive img attributes: `srcset`, `sizes`, `loading`, `decoding`, `data-*`
- ✅ HTML entity conversion: `&nbsp;` → `&#160;` (all common entities)
- ✅ Add `xmlns:epub` namespace to nav.xhtml
- ✅ XHTML-compliant DOCTYPE and structure

**Technical Breakthrough:**
Apple Books doesn't support data URI images. Switched to file-based approach:
- Download images → save as `OEBPS/images/imageN.jpg`
- Replace `src` with local paths: `images/imageN.jpg`
- Add `<item>` entries to OPF manifest

**Problems Solved:**
- Images not visible in Apple Books (data URI limitation)
- "Entity 'nbsp' not defined" XHTML parser errors
- "opening and ending tag mismatch" errors
- Apple Books ignoring `src` when `srcset` present

**Commits:**
- "EPUB: store images as files, add image manifest, fix XHTML entities"
- "Strip img srcset/sizes/loading/decoding/data-*"
- "Add nav xmlns:epub"

---

### Phase 7: Image Format Transcoding (February 2, 2026)

**Date:** February 2, 2026

**Features Implemented:**
- ✅ **WebP → JPEG/PNG transcoding** using UIImage
- ✅ **SVG → PNG transcoding** using WKWebView snapshot
- ✅ Automatic format detection and conversion
- ✅ Fallback to original format if transcoding fails
- ✅ UIKit and WebKit imports for image processing

**Technical Implementation:**

**WebP Transcoding:**
```swift
if let image = UIImage(data: webpData) {
    if let jpeg = image.jpegData(compressionQuality: 0.9) {
        return (jpeg, "image/jpeg", "jpg")
    }
}
```

**SVG Rasterization:**
```swift
private func rasterizeSVGToPNG(svgData: Data) async throws -> Data? {
    // Create HTML with embedded SVG data URI
    // Load in WKWebView (1024×768 canvas)
    // Take snapshot with WKSnapshotConfiguration
    // Export as PNG
}
```

**Problems Solved:**
- Apple Books doesn't render WebP images
- SVG images not supported in many EPUB readers
- Multi-image articles failing to display

**Why This Matters:**
Modern websites serve WebP for file size. Without transcoding, exported EPUBs would have blank images in Apple Books.

**Commit:** "EPUB: transcode WebP to JPEG and SVG to PNG for Apple Books compatibility"

---

## Code Patterns & Conventions

### SwiftUI Patterns

**1. State Management**
```swift
// Use @EnvironmentObject for shared state
@EnvironmentObject var articleStore: ArticleStore

// Use @State for local UI state
@State private var showSheet = false

// Use @Binding for parent-child communication
@Binding var height: CGFloat
```

**2. Conditional Rendering**
```swift
if let article = articleStore.currentArticle {
    ReaderView(article: article)
} else {
    EmptyStateView()
}
```

**3. Async/Await**
```swift
Task {
    do {
        let url = try await epubExporter.export(article: article)
        await MainActor.run {
            epubURL = url
            showShareSheet = true
        }
    } catch {
        // Handle error
    }
}
```

### WKWebView Integration

**1. UIViewRepresentable Pattern**
```swift
struct ArticleContentView: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView { ... }
    func updateUIView(_ webView: WKWebView, context: Context) { ... }
    func makeCoordinator() -> Coordinator { ... }
}
```

**2. Navigation Delegate**
```swift
func webView(_ webView: WKWebView, 
             decidePolicyFor navigationAction: WKNavigationAction,
             decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
    if navigationAction.navigationType == .linkActivated {
        // Open in Safari
        UIApplication.shared.open(url)
        decisionHandler(.cancel)
        return
    }
    decisionHandler(.allow)
}
```

### Memory Management

**1. Weak References in Closures**
```swift
webView.evaluateJavaScript(script) { [weak self] result, error in
    guard let self = self else { return }
    // Use self safely
}
```

**2. Manual Reference Retention**
```swift
// Store strong reference during async operation
ArticleExtractionContext.shared.activeExtractions[url] = webView

// Remove when done
ArticleExtractionContext.shared.activeExtractions.removeValue(forKey: url)
```

### Error Handling

**1. Result Type**
```swift
enum ArticleExtractionError: Error {
    case invalidURL
    case javascriptError
    case parsingFailed
}

completion(.failure(.javascriptError))
```

**2. Optional Chaining**
```swift
guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
      let urlString = components.queryItems?.first(where: { $0.name == "url" })?.value
else {
    return
}
```

---

## External Dependencies

### 1. ZIPFoundation

**Version:** 0.9.20  
**Purpose:** EPUB packaging (ZIP archive creation)  
**Repository:** https://github.com/weichsel/ZIPFoundation  
**License:** MIT

**Installation:** Swift Package Manager

```swift
.package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.20")
```

**Usage:**
```swift
let archive = try Archive(url: epubURL, accessMode: .create)
try archive.addEntry(with: "path/file.txt", type: .file, ...)
```

**Critical API Changes (Fixed Jan 25, 2026):**
- Archive initializer: Changed to throwing `init()`
- CompressionMethod: `.none` and `.deflate` (was enum with different cases)
- addEntry: Changed signature to use `Int64` sizes and Data provider closure

---

### 2. Readability.js

**Version:** Latest (downloaded manually)  
**Purpose:** DOM parsing and article extraction  
**Source:** https://github.com/mozilla/readability  
**License:** Apache 2.0

**Integration:**
- Downloaded as `Readability.js` file
- Added to Xcode project bundle
- Loaded via `Bundle.main.path(forResource:ofType:)`
- Injected inline into JavaScript evaluation

**Why Not NPM/Package:**
iOS doesn't support npm. File is included directly and injected as a string.

---

## API Reference

### ArticleExtractor

```swift
class ArticleExtractor {
    static let shared: ArticleExtractor
    
    func extractArticle(
        from url: URL,
        completion: @escaping (Result<Article, Error>) -> Void
    )
}
```

**Usage:**
```swift
ArticleExtractor.shared.extractArticle(from: url) { result in
    DispatchQueue.main.async {
        switch result {
        case .success(let article):
            articleStore.currentArticle = article
        case .failure(let error):
            print("Error: \(error)")
        }
    }
}
```

### EpubExporter

```swift
class EpubExporter {
    init(session: URLSession = .shared)
    
    func export(article: Article) async throws -> URL
}
```

**Usage:**
```swift
let exporter = EpubExporter()
Task {
    do {
        let epubURL = try await exporter.export(article: article)
        // Share or save
    } catch {
        print("Export failed: \(error)")
    }
}
```

### ArticleStore

```swift
class ArticleStore: ObservableObject {
    @Published var currentArticle: Article?
    @Published var savedArticles: [Article]
    
    func saveArticle(_ article: Article)
    func clearCurrentArticle()
}
```

---

## Common Tasks

### Adding a New Article Property

1. Update `Article` struct in `Models/Article.swift`:
```swift
struct Article {
    let newProperty: String
    // Update init and all existing references
}
```

2. Update JavaScript extraction in `ArticleExtractor.swift`:
```swift
const article = reader.parse();
return JSON.stringify({
    newProperty: article.newProperty || "",
    // ... existing fields
});
```

3. Update decoding in `extractArticle(from:)`:
```swift
let newProperty = json["newProperty"] as? String ?? ""
```

### Adding EPUB Metadata Field

1. Update `opfDocument(article:images:)` in `EpubExporter.swift`:
```swift
<dc:subject>\(article.category)</dc:subject>
```

2. Ensure field exists in `Article` model

### Customizing Reader Styles

Edit CSS in `ArticleContentView.updateUIView()` or `EpubExporter.stylesheet()`:
```swift
body {
    font-size: 20px;  // Change from 19px
    line-height: 1.8; // Change from 1.7
}
```

### Changing EPUB Structure

1. Update `export(article:)` in `EpubExporter.swift`
2. Add new files to `files` array
3. Update OPF manifest in `opfDocument()`

---

## Known Limitations

### Current Limitations

1. **No Article Persistence**
   - Articles are lost when app closes
   - `savedArticles` array exists but not implemented
   - **Solution:** Add UserDefaults or Core Data storage

2. **Single Article at a Time**
   - Can only view one article
   - No history or article list
   - **Solution:** Implement article list view with navigation

3. **No Text Customization**
   - Font size is fixed
   - No theme selection beyond dark mode
   - **Solution:** Add settings view with font/theme controls

4. **Limited Error Feedback**
   - Extraction failures show console logs only
   - No user-facing error messages
   - **Solution:** Add error alerts in UI

5. **WebP Support Depends on iOS Version**
   - UIImage WebP support added in iOS 14+
   - On older devices, transcoding may fail
   - **Solution:** Already has fallback to original format

6. **SVG Rasterization Performance**
   - Each SVG loads a full WKWebView instance
   - Can be slow for many SVGs
   - **Solution:** Consider using Core Graphics-based SVG parser

7. **No Background Downloads**
   - Images downloaded sequentially during EPUB export
   - Large articles can take time
   - **Solution:** Implement parallel downloads with TaskGroup

8. **EPUB Image Quality**
   - JPEG compression at 0.9 quality
   - May reduce image quality
   - **Solution:** Make quality configurable

### Design Decisions

**Why No Backend?**
- Privacy: All processing on-device
- Cost: No server infrastructure needed
- Simplicity: Easier deployment and maintenance
- Offline: Works without internet (after initial page load)

**Why Readability.js and Not Native Parsing?**
- Battle-tested: Used by Firefox Reader Mode
- Universal: Works on any website
- Maintained: Active Mozilla project
- Complete: Handles edge cases we'd miss

**Why EPUB Instead of PDF?**
- Reflowable: Adjusts to screen size
- Accessible: Better screen reader support
- Smaller: More efficient than PDF
- Standard: Works across all ebook readers

---

## Future Enhancements

### Planned Features

1. **Article Persistence**
   - Core Data integration
   - iCloud sync
   - Article library view

2. **Full-text Search**
   - Search across saved articles
   - Highlight matches in reader

3. **Annotations & Highlights**
   - Text selection and highlighting
   - Note-taking
   - Export highlights

4. **Reading Statistics**
   - Track reading time
   - Words read per day
   - Article completion rate

5. **Collections/Tags**
   - Organize articles by topic
   - Smart collections based on metadata

6. **Background Sync**
   - Save articles in background
   - Pre-fetch images for offline

7. **Text-to-Speech**
   - AVSpeechSynthesizer integration
   - Adjustable speed and voice

8. **iPad Optimization**
   - Split view support
   - Article list + reader side-by-side

9. **Watch App**
   - View saved articles on Apple Watch
   - Reading progress sync

10. **Advanced EPUB Features**
    - Table of contents for long articles
    - Chapter detection
    - Custom cover images

---

## Debugging Guide

### Common Issues

**Problem:** Share extension doesn't appear in share sheet

**Solution:**
1. Check both app and extension are signed with same team
2. Verify `NSExtensionActivationRule` in Info.plist
3. Rebuild both targets
4. Delete app from device and reinstall

---

**Problem:** Images not showing in reader view

**Checklist:**
1. Is `baseURL` being passed to ArticleContentView? (Check `URL(string: article.url)`)
2. Are images using absolute URLs? (Check src in HTML)
3. Is WKWebView configuration allowing remote loads? (Check `defaultWebpagePreferences`)
4. Check Console for CORS or network errors

---

**Problem:** EPUB images blank in Apple Books

**Checklist:**
1. Are images saved as files (not data URIs)?
2. Are images in OPF manifest?
3. Are `src` attributes using relative paths (`images/imageN.jpg`)?
4. Are `srcset` attributes stripped?
5. Is image format supported (JPEG/PNG, not WebP/SVG)?

---

**Problem:** "Entity 'nbsp' not defined" in EPUB

**Solution:** Ensure `replaceHTMLEntities()` is called before XHTML generation. Converts `&nbsp;` → `&#160;`.

---

**Problem:** App crashes when extracting article

**Checklist:**
1. Is WKWebView retained during extraction? (Check `ArticleExtractionContext`)
2. Is Readability.js in app bundle?
3. Are you calling on main thread when needed?
4. Check JavaScript console for errors

---

## Testing Checklist

### Manual Testing

**Article Extraction:**
- [ ] Share from Safari works
- [ ] Share from Chrome works
- [ ] Manual URL input works
- [ ] Article displays with images
- [ ] Dark mode toggles correctly
- [ ] Links open in Safari
- [ ] Close button returns to empty state

**EPUB Export:**
- [ ] Export menu appears
- [ ] Progress overlay shows
- [ ] Share sheet appears with .epub file
- [ ] Can save to Files app
- [ ] Can open in Apple Books
- [ ] Images display correctly in Books
- [ ] Metadata is correct (title, author)
- [ ] Table of contents works

**Edge Cases:**
- [ ] Very long articles (10,000+ words)
- [ ] Articles with many images (20+)
- [ ] Articles with no images
- [ ] Articles with WebP images
- [ ] Articles with SVG images
- [ ] Paywalled content (should fail gracefully)
- [ ] JavaScript-heavy sites

---

## Contributing Guidelines

### Code Style

- Use SwiftUI where possible
- Prefer `async/await` over completion handlers for new code
- Use `guard` for early returns
- Comment complex logic, not obvious code
- Keep functions under 50 lines when possible

### Commit Messages

Format: `<area>: <description>`

Examples:
- `EPUB: add image transcoding`
- `ReaderView: fix scrolling issue`
- `ArticleExtractor: handle timeout errors`

### Pull Request Template

```markdown
## Changes
- What changed and why

## Testing
- How to test the changes

## Screenshots
- If UI changes

## Breaking Changes
- Any API or behavior changes
```

---

## License

MIT License - See LICENSE file for details

---

**Document Maintained By:** Pulkit Vashishta  
**Repository:** https://github.com/pulkitv/ReaderViewApp  
**Contact:** [Your contact info]

---

*This documentation should be updated with each significant change to the project. Add new sections as features are developed and update the timeline chronologically.*
