# iOS Reader View App

A native iOS app that extracts and displays articles in a clean, reader-friendly format using client-side JavaScript injection (similar to browser reader mode extensions).

## Features

- **Share Extension**: Share any URL from Safari, Chrome, or any iOS app directly to the Reader View app
- **Client-side Extraction**: Uses Mozilla's Readability.js injected via WKWebView to extract article content
- **Clean Reader UI**: Beautiful, distraction-free reading experience
- **Works on Any Site**: Extracts content from Medium, NYTimes, blogs, and any article you can access
- **Dark Mode Support**: Automatically adapts to system appearance
- **Manual URL Input**: Paste URLs directly into the app

## How It Works

1. **Share Extension**: When you share a URL from any app, iOS displays the Reader View app as a share target
2. **URL Passing**: The share extension passes the URL to the main app via a custom URL scheme
3. **WebView Loading**: The main app loads the URL in a WKWebView
4. **JS Injection**: After the page loads, Readability.js is injected and executed client-side
5. **Content Extraction**: The JavaScript extracts the article title, author, content, and images
6. **Reader Display**: The extracted content is displayed in a beautiful, readable format

## Project Structure

```
ReaderViewApp/
├── ReaderViewApp/
│   ├── ReaderViewApp.swift          # Main app entry point
│   ├── ContentView.swift            # Home screen with empty state
│   ├── Models/
│   │   └── Article.swift            # Article data model
│   ├── Services/
│   │   └── ArticleExtractor.swift   # WebView-based extraction service
│   └── Views/
│       └── ReaderView.swift         # Reader view UI with styled content
└── ShareExtension/
    ├── ShareViewController.swift    # Share extension handler
    └── Info.plist                   # Share extension configuration
```

## Setup Instructions

### Prerequisites
- Xcode 15.0 or later
- iOS 16.0+ deployment target
- macOS for development

### Step 1: Download Readability.js

```bash
cd ReaderViewApp/ReaderViewApp
curl -o Readability.js https://raw.githubusercontent.com/mozilla/readability/main/Readability.js
```

### Step 2: Create Xcode Project

1. Open Xcode
2. Create a new project: File → New → Project
3. Choose "App" template under iOS
4. Project name: **ReaderViewApp**
5. Interface: **SwiftUI**
6. Language: **Swift**

### Step 3: Add Files to Xcode

1. Drag all `.swift` files from the folder structure into your Xcode project
2. Add `Readability.js` to the project: File → Add Files → Select Readability.js
3. Ensure "Copy items if needed" and "Add to targets: ReaderViewApp" are checked

### Step 4: Create Share Extension

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

## How It's Different from the Web App

✅ **Native iOS Experience**: Feels like a real iOS app with native UI components  
✅ **System Share Sheet Integration**: Appears in the share menu of every app  
✅ **Offline Capability**: Can save articles for later (with additional code)  
✅ **Better Performance**: Native rendering and no CORS issues  
✅ **Privacy**: All extraction happens on-device, no server needed

## Technical Details

### Article Extraction Flow
1. WKWebView loads the URL
2. Once loaded, JavaScript (Readability.js) is injected
3. Readability parses the DOM and extracts article content
4. Result is serialized to JSON and passed back to Swift
5. Swift parses JSON and creates an Article object
6. Article is displayed in a styled WKWebView

### Why This Works
- **Client-side**: Extraction happens in the user's context (no server blocking)
- **Native WebView**: Full browser capabilities, handles JavaScript, cookies, auth
- **Mozilla Readability**: Battle-tested extraction algorithm used by Firefox
- **No CORS**: Everything runs locally on the device

## Next Steps

To enhance the app further:
- [ ] Add article saving/history feature
- [ ] Implement offline reading
- [ ] Add text-to-speech
- [ ] Export to PDF or EPUB
- [ ] Customize font size and theme
- [ ] Add highlight and annotation features

## Troubleshooting

**Share extension doesn't appear:**
- Make sure both targets are signed with the same team
- Check that NSExtensionActivationRule is properly configured
- Verify app groups are set up correctly

**Extraction fails:**
- Check Console for JavaScript errors
- Verify Readability.js is included in the app bundle
- Some sites may have complex JavaScript that delays content loading

**App doesn't open from share:**
- Verify URL scheme is registered
- Check that onOpenURL handler is implemented
- Ensure the URL is properly encoded

## License

MIT License - Feel free to use and modify for your projects!
