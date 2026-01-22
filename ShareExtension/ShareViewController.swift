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
        }
    }
    
    private func openMainApp(with url: URL) {
        // Create a URL scheme to open the main app with the shared URL
        let urlString = "readerviewapp://share?url=\(url.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        
        guard let appURL = URL(string: urlString) else {
            extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
            return
        }
        
        // Use the extension context to open URL in the main app
        var responder: UIResponder? = self
        while responder != nil {
            if let application = responder as? UIApplication {
                application.open(appURL, options: [:]) { [weak self] _ in
                    self?.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
                }
                return
            }
            responder = responder?.next
        }
        
        // Fallback using the openURL selector
        self.openURL(appURL)
    }
    
    @objc private func openURL(_ url: URL) {
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
