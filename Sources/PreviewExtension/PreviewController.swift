import AppKit
import PreviewCore
import PreviewUI
import QuickLookUI

@objc(PreviewController)
final class PreviewController: NSViewController, QLPreviewingController {
    private let preview = PreviewViewController()
    private var requestID = UUID()

    override func loadView() {
        addChild(preview)
        view = preview.view
        preferredContentSize = NSSize(width: 800, height: 600)
    }

    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        loadViewIfNeeded()
        let id = UUID()
        requestID = id
        preview.display(.failure(NSError(domain: "Fileglint", code: 0, userInfo: [NSLocalizedDescriptionKey: "Loading preview…"])), sourceURL: url)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = Result { try PreviewDocument.read(url) }
            DispatchQueue.main.async { [weak self] in
                if self?.requestID == id { self?.preview.display(result, sourceURL: url) }
                // Display read/parse failures inline rather than replacing them with a generic OS failure.
                handler(nil)
            }
        }
    }
}
