import AppKit
import PreviewUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private var sampleWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let appMenu = NSMenu()
        let appItem = NSMenuItem()
        appMenu.addItem(appItem)
        let submenu = NSMenu()
        submenu.addItem(withTitle: "Quit Fileglint", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = submenu
        let editItem = NSMenuItem()
        appMenu.addItem(editItem)
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit
        NSApp.mainMenu = appMenu

        let title = NSTextField(labelWithString: "Fileglint")
        title.font = .boldSystemFont(ofSize: 24)
        let instructions = NSTextField(wrappingLabelWithString: "Preview JSON, YAML and TOML in Finder.\n\n1. Keep this app installed.\n2. Enable Fileglint in System Settings → General → Login Items & Extensions → Quick Look if needed (location varies by macOS).\n3. Select a supported file in Finder and press Space.\n\nUse Raw to preserve the original text. Prettified changes only the display. Quick Look’s Open action and Finder’s Open With open the original file in an editor.")
        let sample = NSButton(title: "Try Sample", target: self, action: #selector(showSample))
        sample.setAccessibilityIdentifier("try-sample")
        let stack = NSStackView(views: [title, instructions, sample])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 20
        stack.edgeInsets = NSEdgeInsets(top: 28, left: 28, bottom: 28, right: 28)
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 540, height: 400), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window?.title = "Fileglint"
        window?.contentView = stack
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func showSample() {
        let controller = PreviewViewController()
        let source = #"{"name":"Fileglint","enabled":true,"items":[1,2,3]}"#
        // The sample follows the same parser and view paths as the extension.
        controller.display(Result { try .init(data: Data(source.utf8), format: .json) })
        sampleWindow = NSWindow(contentViewController: controller)
        sampleWindow?.title = "Sample Preview"
        sampleWindow?.setContentSize(NSSize(width: 800, height: 600))
        sampleWindow?.makeKeyAndOrderFront(nil)
    }
}

MainActor.assumeIsolated {
    let application = NSApplication.shared
    let delegate = AppDelegate()
    application.delegate = delegate
    application.setActivationPolicy(.regular)
    application.run()
}
