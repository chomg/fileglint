import AppKit
import PreviewOpening

@MainActor
public final class OpenWithController: NSObject {
    public let mainButton = NSButton(title: "Open", target: nil, action: nil)
    public let menuButton = NSButton()
    public let status = NSTextField(wrappingLabelWithString: "")
    public let buttons = NSStackView()
    private let discovery: ApplicationDiscovering
    private let opener: FileOpening
    private var source: URL?
    private var generation = UUID()
    private var queryID: UUID?
    private var queryTimeoutWork: DispatchWorkItem?
    private var catalog: ApplicationCatalog?
    private var operation: OpeningCancellation?
    private var opening = false
    private var menu: NSMenu?
    var queryTimeout: TimeInterval = 10
    var presentMenu: (NSMenu, NSButton) -> Void = { menu, button in
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: -4), in: button)
    }

    public init(discovery: ApplicationDiscovering? = nil, opener: FileOpening? = nil) {
        self.discovery = discovery ?? WorkspaceApplicationDiscovery()
        self.opener = opener ?? XPCFileOpener()
        super.init()
        mainButton.target = self
        mainButton.action = #selector(openDefault)
        mainButton.bezelStyle = .rounded
        mainButton.setAccessibilityIdentifier("open-default-application")
        mainButton.cell?.lineBreakMode = .byTruncatingMiddle
        mainButton.widthAnchor.constraint(lessThanOrEqualToConstant: 260).isActive = true
        menuButton.image = NSImage(systemSymbolName: "chevron.down", accessibilityDescription: nil)
        menuButton.bezelStyle = .rounded
        menuButton.target = self
        menuButton.action = #selector(showApplications)
        menuButton.toolTip = "Choose an application for this file"
        menuButton.setAccessibilityIdentifier("choose-application")
        menuButton.setAccessibilityLabel("Choose application")
        menuButton.widthAnchor.constraint(equalToConstant: 28).isActive = true
        buttons.addArrangedSubview(mainButton)
        buttons.addArrangedSubview(menuButton)
        buttons.spacing = 0
        buttons.setHuggingPriority(.required, for: .horizontal)
        status.setAccessibilityIdentifier("opening-status")
        status.textColor = .secondaryLabelColor
        mainButton.nextKeyView = menuButton
        setSource(nil)
    }

    public func setSource(_ source: URL?) {
        generation = UUID()
        queryID = nil
        queryTimeoutWork?.cancel()
        operation?.cancel()
        operation = nil
        menu?.cancelTrackingWithoutAnimation()
        menu = nil
        self.source = source
        catalog = nil
        opening = false
        buttons.isHidden = source == nil
        mainButton.title = "Open"
        mainButton.setAccessibilityLabel("Open original file")
        mainButton.isEnabled = false
        menuButton.isEnabled = source != nil
        setStatus("")
        if source != nil { refresh { _ in } }
    }

    private func setStatus(_ text: String) {
        status.stringValue = text
        status.isHidden = text.isEmpty
    }

    private func apply(_ catalog: ApplicationCatalog) {
        self.catalog = catalog
        if let app = catalog.defaultApplication {
            mainButton.title = "Open with \(app.name)"
            mainButton.toolTip = app.url.path
            mainButton.setAccessibilityLabel("Open original file with \(app.name)")
        } else {
            mainButton.title = "No default app"
            mainButton.toolTip = "Choose an application using the arrow"
            mainButton.setAccessibilityLabel("No default application")
        }
        mainButton.isEnabled = catalog.defaultApplication != nil && !opening
        menuButton.isEnabled = !opening
        if catalog.applications.isEmpty { setStatus("No compatible applications are installed. Install an application and try the arrow again.") }
        else if catalog.defaultApplication == nil { setStatus(OpeningError.noDefault.localizedDescription) }
        else if !opening { setStatus("") }
    }

    private func refresh(_ completion: @escaping (ApplicationCatalog) -> Void) {
        guard let source else { return }
        let generation = self.generation
        let query = UUID()
        queryID = query
        queryTimeoutWork?.cancel()
        setStatus("Finding applications…")
        let timeout = DispatchWorkItem { [weak self] in
            guard let self, self.generation == generation, self.queryID == query else { return }
            self.queryID = nil
            self.catalog = nil
            self.mainButton.isEnabled = false
            self.setStatus("Finding applications timed out. Try the arrow again or use Finder’s Open With menu.")
        }
        queryTimeoutWork = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + queryTimeout, execute: timeout)
        discovery.discover(for: source) { [weak self] result in
            guard let self, self.generation == generation, self.queryID == query else { return }
            self.queryID = nil
            self.queryTimeoutWork?.cancel()
            switch result {
            case .success(let catalog): self.apply(catalog); completion(catalog)
            case .failure(let error):
                self.catalog = nil
                self.mainButton.isEnabled = false
                self.setStatus(error.localizedDescription)
            }
        }
    }

    @objc public func showApplications() {
        guard !opening else { return }
        refresh { [weak self] catalog in
            guard let self, let source = self.source else { return }
            let menu = NSMenu(title: "Open With")
            menu.autoenablesItems = false
            for app in catalog.applications {
                let isDefault = app.url == catalog.defaultURL
                let item = NSMenuItem(title: catalog.label(for: app) + (isDefault ? " (Default)" : ""), action: #selector(self.selectApplication(_:)), keyEquivalent: "")
                item.target = self
                item.state = isDefault ? .on : .off
                let icon = NSWorkspace.shared.icon(forFile: app.url.path)
                icon.size = NSSize(width: 16, height: 16)
                item.image = icon
                item.representedObject = MenuAction(source: source, generation: self.generation, application: app.url)
                menu.addItem(item)
            }
            if catalog.applications.isEmpty {
                let item = NSMenuItem(title: "No compatible applications", action: nil, keyEquivalent: "")
                item.isEnabled = false
                menu.addItem(item)
            }
            self.menu = menu
            self.presentMenu(menu, self.menuButton)
        }
    }

    @objc public func openDefault() {
        guard !opening else { return }
        refresh { [weak self] catalog in
            guard let self else { return }
            guard catalog.defaultApplication != nil else { self.setStatus(OpeningError.noDefault.localizedDescription); return }
            self.launch(application: nil)
        }
    }

    @objc func selectApplication(_ item: NSMenuItem) {
        guard !opening, let action = item.representedObject as? MenuAction,
              action.generation == generation, action.source == source else { return }
        refresh { [weak self] catalog in
            guard let self else { return }
            guard catalog.applications.contains(where: { $0.url == action.application }) else {
                self.setStatus(OpeningError.unavailableApplication.localizedDescription)
                return
            }
            self.launch(application: action.application)
        }
    }

    private func launch(application: URL?) {
        guard let source else { return }
        let generation = self.generation
        opening = true
        mainButton.isEnabled = false
        menuButton.isEnabled = false
        setStatus("Opening original file…")
        operation = opener.open(source, application: application) { [weak self] result in
            guard let self, self.generation == generation else { return }
            self.operation = nil
            self.opening = false
            if let catalog = self.catalog { self.apply(catalog) }
            switch result {
            case .success: self.setStatus("")
            case .failure(let error): self.setStatus(error.localizedDescription)
            }
        }
    }
}

private struct MenuAction {
    let source: URL
    let generation: UUID
    let application: URL
}
