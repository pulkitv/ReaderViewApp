import UIKit
import Social
import MobileCoreServices
import UniformTypeIdentifiers

class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        handleSharedURL()
    }
    
    private func handleSharedURL() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let itemProvider = extensionItem.attachments?.first else {
            extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
            return
        }
        
        if itemProvider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            itemProvider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] (item, error) in
                guard let self = self else { return }
                
                if let error = error {
                    print("Error loading URL: \(error.localizedDescription)")
                    self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
                    return
                }
                
                if let url = item as? URL {
                    self.openMainApp(with: url)
                } else if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                    self.openMainApp(with: url)
                } else {
                    self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
                }
            }
        } else if itemProvider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            itemProvider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { [weak self] (item, error) in
                guard let self = self else { return }
                
                if let urlString = item as? String, let url = URL(string: urlString) {
                    self.openMainApp(with: url)
                } else {
                    self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
                }
            }
        } else {
            extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
        }
    }
    
    private func openMainApp(with url: URL) {
        // Create a URL scheme to open the main app with the shared URL
        let urlString = "readerviewapp://share?url=\(url.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"

        print("🔗 ShareExtension: Opening URL scheme: \(urlString)")

        guard let appURL = URL(string: urlString) else {
            print("❌ ShareExtension: Failed to create URL")
            extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
            return
        }

        print("🔗 ShareExtension: Attempting to open app with URL")

        // Try to open using UIApplication through responder chain
        var responder: UIResponder? = self
        var foundApplication = false
        
        while responder != nil {
            if let application = responder as? UIApplication {
                print("✅ ShareExtension: Found UIApplication, opening...")
                foundApplication = true
                application.open(appURL, options: [:]) { [weak self] success in
                    print("✅ ShareExtension: Open result: \(success)")
                    self?.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
                }
                return
            }
            responder = responder?.next
        }
        
        if !foundApplication {
            print("⚠️ ShareExtension: UIApplication not found, using selector")
            openURLViaSelector(appURL)
        }
    }
    
    private func openURLViaSelector(_ url: URL) {
        let selector = NSSelectorFromString("openURL:")
        var responder: UIResponder? = self
        
        while responder != nil {
            if responder?.responds(to: selector) == true {
                responder?.perform(selector, with: url)
                break
            }
            responder = responder?.next
        }
        
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}
