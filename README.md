# iOS Reader View App

A native iOS app that extracts and displays articles in a clean, reader-friendly format using client-side JavaScript injection. Features EPUB export with automatic image format conversion for maximum compatibility.

**Version:** 2.0  
**Last Updated:** February 2, 2026  
**iOS:** 16.0+

---

## ✨ Features

### Core Reading Experience
- **Share Extension**: Share any URL from Safari, Chrome, or any iOS app directly to Reader View
- **Client-side Extraction**: Uses Mozilla's Readability.js injected via WKWebView
- **Clean Reader UI**: Beautiful, distraction-free reading with optimized typography
- **Dark Mode Support**: Automatically adapts to system appearance
- **Smart Image Loading**: Resolves relative URLs and loads external images seamlessly
- **Manual URL Input**: Paste URLs directly into the app

### EPUB Export (NEW! 🎉)
- **One-Tap Export**: Convert any article to EPUB 3.0 format
- **Embedded Images**: Downloads and packages all article images
- **Format Transcoding**: Automatically converts WebP → JPEG and SVG → PNG for universal compatibility
- **Apple Books Ready**: Optimized for Apple Books and all major EPUB readers
- **Offline Reading**: Save articles permanently with full formatting and images
- **Standards Compliant**: Valid EPUB 3.0 with proper XHTML and metadata

### Technical Highlights
- **Privacy-First**: All extraction happens on-device, no data sent to servers
- **Universal Compatibility**: Works with Medium, NYTimes, blogs, and most websites
- **Smart Resource Management**: Image size limits and download timeouts prevent memory issues
- **Robust HTML Processing**: Handles malformed HTML, void tags, and HTML entities correctly

---

## How It Works

1. **Share Extension**: When you share a URL from any app, iOS displays the Reader View app as a share target
2. **URL Passing**: The share extension passes the URL to the main app via a custom URL scheme
3. **WebView Loading**: The main app loads the URL in a WKWebView
4. **JS Injection**: After the page loads, Readability.js is injected and executed client-side
5. **Content Extraction**: The JavaScript extracts the article title, author, content, and images
6. **Reader Display**: The extracted content is displayed in a beautiful, readable format

## 🏗️ Project Structure

```
ReaderViewApp/
├── ReaderViewApp/
│   ├── ReaderViewApp/
│   │   ├── ReaderViewApp.swift          # Main app entry point with URL scheme handling
│   │   ├── ContentView.swift            # Home screen with empty state & manual input
│   │   ├── Models/
│   │   │   └── Article.swift            # Article data model + ArticleStore
│   │   ├── Services/
│   │   │   ├── ArticleExtractor.swift   # WebView-based extraction with Readability.js
│   │   │   └── EpubExporter.swift       # EPUB 3.0 generation with image transcoding
│   │   ├── Views/
│   │   │   └── ReaderView.swift         # Reader UI with styled content + export
│   │   └── Readability.js               # Mozilla's article extraction library
│   └── ShareExtension/
│       ├── ShareViewController.swift    # iOS share extension handler
│       └── Info.plist                   # Share extension configuration
├── Package.resolved                     # ZIPFoundation dependency
├── README.md                            # This file
└── PROJECT_DOCUMENTATION.md             # Comprehensive technical documentation
```

### Key Files Explained

- **ArticleExtractor.swift**: Manages WKWebView lifecycle, injects Readability.js, and extracts article JSON
- **EpubExporter.swift**: Downloads images, transcodes WebP/SVG, builds EPUB structure, and packages as ZIP
- **ReaderView.swift**: Displays articles with WKWebView, handles image loading via baseURL, provides EPUB export UI
- **ArticleStore**: Single source of truth for app state using Combine's `@Published`

📖 **For detailed architecture and implementation details, see [PROJECT_DOCUMENTATION.md](PROJECT_DOCUMENTATION.md)**

---

## 🚀 Setup Instructions

### Prerequisites
- Xcode 15.0 or later
- iOS 16.0+ deployment target
- macOS for development

### Quick Start

1. **Clone the repository**
   ```bash
   git clone https://github.com/pulkitv/ReaderViewApp.git
   cd ReaderViewApp
   ```

2. **Download Readability.js**
   ```bash
   cd ReaderViewApp/ReaderViewApp/ReaderViewApp
   curl -o Readability.js https://raw.githubusercontent.com/mozilla/readability/main/Readability.js
   ```

3. **Open in Xcode**
   ```bash
   open ReaderViewApp.xcodeproj
   ```

4. **Install Dependencies**
   - Xcode will automatically resolve Swift Package Manager dependencies (ZIPFoundation)
   - Wait for packages to download

5. **Configure Signing**
   - Select ReaderViewApp target → Signing & Capabilities
   - Choose your development team
   - Repeat for ShareExtension target

6. **Build and Run**
   - Select your device or simulator
   - Press Cmd+R to build and run

### Detailed Setup (First-Time Projects)

If you're creating from scratch, follow these detailed steps:

1. File → New → Target
2. Choose "Share Extension" under iOS
3. Product Name: **ShareExtension**
4. Replace the default `ShareViewController.swift` with the provided one
5. Update `Info.plist` for the ShareExtension:

```xml
<key>NSExtension</key>
<dict>
    <key>NSExtensionAttributes</key>
    <dict>
        <key>NSExtensionActivationRule</key>
        <dict>
            <key>NSExtensionActivationSupportsWebURLWithMaxCount</key>
            <integer>1</integer>
            <key>NSExtensionActivationSupportsWebPageWithMaxCount</key>
            <integer>1</integer>
        </dict>
    </dict>
    <key>NSExtensionMainStoryboard</key>
    <string>MainInterface</string>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.share-services</string>
</dict>
```

### Step 5: Configure URL Scheme

1. Select your main app target in Xcode
2. Go to Info tab
3. Add a URL Type:
   - Identifier: `com.yourname.readerviewapp`
   - URL Schemes: `readerviewapp`

### Step 6: Handle URL Scheme in App

Add this to `ReaderViewApp.swift`:

```swift
@main
struct ReaderViewApp: App {
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
        guard url.scheme == "readerviewapp",
              url.host == "share",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let urlString = components.queryItems?.first(where: { $0.name == "url" })?.value,
              let articleURL = URL(string: urlString) else {
            return
        }
        
        ArticleExtractor.shared.extractArticle(from: articleURL) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let article):
                    articleStore.currentArticle = article
                case .failure(let error):
                    print("Extraction error: \(error)")
                }
            }
        }
    }
}
```

### Step 7: Add Required Capabilities

1. Select your main app target
2. Signing & Capabilities tab
3. Add "App Groups" capability
4. Create an app group: `group.com.yourname.readerviewapp`
5. Add the same app group to the ShareExtension target

### Step 8: Build and Run

1. Select your device or simulator
2. Build the project (Cmd+B)
3. Run the app (Cmd+R)

## Usage

### Method 1: Share from Any App
1. Open Safari, Chrome, or any app with a shareable URL
2. Tap the Share button
3. Select "Reader View" from the share sheet
4. The article will open in the Reader View app

### Method 2: Manual URL Input
1. Open the Reader View app
2. Tap "Or paste a URL manually"
3. Enter the article URL
4. Tap "Extract Article"

### Method 3: EPUB Export
1. Open an article in Reader View
2. Tap the menu icon (•••) in the top-right
3. Select "Export as EPUB"
4. Wait for image processing and packaging
5. Choose where to save or share the EPUB file
6. Open in Apple Books or any EPUB reader

---

## 🎯 How It Works

### Article Extraction Flow
1. **URL Reception**: Via share extension or manual input
2. **WebView Loading**: URL loaded in background WKWebView
3. **JS Injection**: Readability.js injected after page load (with 1s delay for dynamic content)
4. **Content Parsing**: JavaScript parses DOM and extracts clean article data
5. **Data Transfer**: JSON result passed back to Swift
6. **Rendering**: Extracted HTML displayed in styled WKWebView with proper baseURL for images

### EPUB Export Flow
1. **Image Extraction**: Regex scan HTML for `<img>` tags
2. **Download & Transcode**: 
   - Download images with 12s timeout
   - Detect WebP → convert to JPEG (90% quality)
   - Detect SVG → rasterize to PNG (1024×768px)
3. **HTML Sanitization**: 
   - Strip `srcset`, `sizes`, `loading` attributes
   - Replace HTML entities (`&nbsp;` → `&#160;`)
   - Normalize void tags (`<img>` → `<img />`)
4. **EPUB Assembly**: Build mimetype, container, OPF manifest, nav, XHTML, CSS, images
5. **ZIP Packaging**: Create EPUB archive with ZIPFoundation
6. **Share**: Present system share sheet with .epub file

---

## 📚 Documentation

- **README.md** (this file): Quick start guide and basic usage
- **[PROJECT_DOCUMENTATION.md](PROJECT_DOCUMENTATION.md)**: Comprehensive technical documentation including:
  - Detailed architecture diagrams
  - Component responsibilities and interactions
  - Chronological feature timeline with dates
  - Code patterns and conventions
  - API reference
  - Debugging guides
  - Future enhancement roadmap

💡 **For AI Coding Assistants:** Start by reading PROJECT_DOCUMENTATION.md to understand the full codebase before making changes.

---

## 🔧 Technical Details

### Key Technologies
- **SwiftUI**: Modern declarative UI framework
- **WKWebView**: Browser engine for page loading and rendering
- **Readability.js**: Mozilla's battle-tested article extraction
- **ZIPFoundation**: EPUB packaging (Swift Package Manager)
- **Combine**: Reactive state management with `@Published`

### Why This Approach?

✅ **Native Performance**: Faster than web apps, smoother scrolling  
✅ **Privacy**: All processing on-device, zero data sent to servers  
✅ **No CORS Issues**: Runs in user's browser context  
✅ **Universal**: Works on any site the user can access  
✅ **Offline Capable**: EPUB export enables permanent offline access  

---

## 🆕 Recent Updates

### Version 2.0 (February 2, 2026)
- ✅ EPUB export with embedded images
- ✅ WebP → JPEG and SVG → PNG transcoding
- ✅ Apple Books compatibility optimizations
- ✅ Smart image loading with baseURL resolution
- ✅ Responsive attribute stripping for EPUB
- ✅ XHTML entity conversion
- ✅ Performance improvements and memory optimization

### Version 1.5 (January 25-26, 2026)
- ✅ Fixed image display in reader view
- ✅ WKWebView configuration improvements
- ✅ Enhanced scrolling and typography
- ✅ Loading indicators and progress overlays
- ✅ Deprecated API fixes

### Version 1.0 (January 2026)
- ✅ Initial release with core extraction
- ✅ Share extension integration
- ✅ Dark mode support

See [PROJECT_DOCUMENTATION.md](PROJECT_DOCUMENTATION.md) for detailed feature timeline.

---

## ⚠️ Known Limitations

- **No Article Persistence**: Articles are cleared when app closes (future enhancement)
- **Single Article View**: Can only view one article at a time
- **No Text Customization**: Fixed font size and theme (beyond dark mode)
- **Sequential Image Downloads**: EPUB export processes images one-by-one (can be slow for image-heavy articles)

See PROJECT_DOCUMENTATION.md for complete limitations list and planned enhancements.

---

## 🛠️ Troubleshooting

### Share Extension Issues

**Share extension doesn't appear in share sheet:**
- Ensure both app and extension are signed with the same development team
- Verify `NSExtensionActivationRule` in ShareExtension Info.plist
- Rebuild both targets (Cmd+Shift+K then Cmd+B)
- Delete app from device and reinstall

**App doesn't open from share extension:**
- Check URL scheme is registered: `readerviewapp`
- Verify `.onOpenURL` handler is implemented in ReaderViewApp.swift
- Ensure URL is properly percent-encoded

### Extraction Issues

**Extraction fails or shows blank content:**
- Check Console.app for JavaScript errors
- Verify Readability.js is in app bundle: `Bundle.main.path(forResource: "Readability", ofType: "js")`
- Some sites with heavy JavaScript may need longer delay (increase from 1s in ArticleExtractor)
- Paywalled/login-required content will fail (by design)

### Image Issues

**Images not showing in reader view:**
- Verify article.url is valid (used as baseURL)
- Check browser Console for CORS errors
- Ensure WKWebView configuration allows remote loads
- Images with complex authentication may not load

**Images missing in EPUB:**
- Check network connectivity during export
- Verify images are under 8MB size limit
- Some sites block image downloads (403/404 errors)
- Check Console for image download failures

### EPUB Issues

**"Entity 'nbsp' not defined" error:**
- Should be automatically fixed by entity conversion
- If persists, check `replaceHTMLEntities()` is called in EpubExporter

**Images blank in Apple Books:**
- Ensure export completed successfully
- WebP/SVG images should auto-convert (if failing, check iOS version)
- Verify OPF manifest includes image entries

**EPUB won't open:**
- Check file size (corrupt if too small, ~1KB)
- Verify mimetype is first entry and uncompressed
- Use EPUB validator: https://www.pagina.gmbh/produkte/epub-checker/

### Performance Issues

**App crashes during extraction:**
- Memory spike from large images: reduce `maxImageBytes` in EpubExporter
- WKWebView memory leak: check `ArticleExtractionContext` cleanup
- Too many simultaneous extractions: wait for completion before new extraction

---

## 🤝 Contributing

Contributions are welcome! Please read [PROJECT_DOCUMENTATION.md](PROJECT_DOCUMENTATION.md) for:
- Code style guidelines
- Commit message format
- Pull request template
- Architecture patterns

### Development Workflow

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Read PROJECT_DOCUMENTATION.md to understand architecture
4. Make your changes
5. Test thoroughly (see testing checklist in docs)
6. Commit with descriptive messages: `EPUB: add NCX generation`
7. Push and create Pull Request

---

## 📝 License

MIT License - See [LICENSE](LICENSE) file for details.

---

## 📞 Contact & Support

**Repository:** https://github.com/pulkitv/ReaderViewApp  
**Issues:** https://github.com/pulkitv/ReaderViewApp/issues  
**Documentation:** [PROJECT_DOCUMENTATION.md](PROJECT_DOCUMENTATION.md)

---

## 🙏 Acknowledgments

- **Mozilla** for Readability.js
- **ZIPFoundation** for EPUB packaging
- **Apple** for excellent SwiftUI and WKWebView APIs

---

## 🗺️ Roadmap

### Near Term (Q1 2026)
- [ ] Article persistence with Core Data
- [ ] Article history and library view
- [ ] Text size customization
- [ ] Multiple theme options

### Medium Term (Q2 2026)
- [ ] Full-text search across saved articles
- [ ] Tags and collections
- [ ] Highlights and annotations
- [ ] iCloud sync

### Long Term (2026+)
- [ ] iPad optimization with split view
- [ ] Apple Watch companion app
- [ ] Text-to-speech integration
- [ ] Advanced EPUB features (TOC, chapters)

See [PROJECT_DOCUMENTATION.md](PROJECT_DOCUMENTATION.md) for complete roadmap.

---

**Last Updated:** February 2, 2026  
**Version:** 2.0  
**Maintained By:** Pulkit Vashishta
