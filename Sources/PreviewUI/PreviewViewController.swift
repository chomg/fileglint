import AppKit
import PreviewCore

@MainActor
public final class PreviewViewController: NSViewController {
    public let mode = NSSegmentedControl(labels: ["Raw", "Prettified"], trackingMode: .selectOne, target: nil, action: nil)
    public let textView = FoldingTextView()
    public let status = NSTextField(wrappingLabelWithString: "Choose a file in Finder and press Space.")
    public let opening = OpenWithController()
    private var document: PreviewDocument?

    public override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        mode.target = self
        mode.action = #selector(updateDisplayedMode)
        mode.selectedSegment = 0
        mode.setAccessibilityIdentifier("preview-mode")
        mode.setAccessibilityLabel("Preview mode")
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textContainerInset = NSSize(width: 14, height: 14)
        textView.autoresizingMask = [.width]
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.setAccessibilityIdentifier("preview-content")
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.documentView = textView
        status.setAccessibilityIdentifier("preview-status")
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let header = NSStackView(views: [mode, spacer, opening.buttons])
        header.alignment = .centerY
        header.spacing = 8
        mode.nextKeyView = opening.mainButton
        opening.menuButton.nextKeyView = textView
        textView.afterDisclosures = mode
        let stack = NSStackView(views: [header, status, opening.status, scroll])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -12),
            header.widthAnchor.constraint(equalTo: stack.widthAnchor),
            opening.status.widthAnchor.constraint(equalTo: stack.widthAnchor),
            scroll.widthAnchor.constraint(equalTo: stack.widthAnchor),
            status.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
    }

    public func display(_ result: Result<PreviewDocument, Error>, sourceURL: URL? = nil) {
        loadViewIfNeeded()
        mode.selectedSegment = 0
        opening.setSource(sourceURL)
        switch result {
        case .success(let document):
            self.document = document
            mode.setEnabled(true, forSegment: 0)
            mode.setEnabled(document.pretty != nil, forSegment: 1)
        case .failure(let error):
            document = nil
            textView.setDocument(NSAttributedString(string: ""), regions: [])
            mode.setEnabled(false, forSegment: 0)
            mode.setEnabled(false, forSegment: 1)
            status.stringValue = error.localizedDescription
        }
        updateDisplayedMode()
    }

    @objc public func updateDisplayedMode() {
        guard let document else { return }
        let explanation = document.format == .json ? "Prettified changes spacing only." : "Prettified preserves comments; spacing may change."
        let folding = mode.selectedSegment == 1 && !document.foldRegions.isEmpty ? " Fold sections with the arrows; Copy includes hidden text." : ""
        status.stringValue = document.formattingError ?? "\(document.format.rawValue.uppercased()) · Read only · \(explanation)\(folding)"
        let source = mode.selectedSegment == 1 ? (document.pretty ?? document.raw) : document.raw
        let full = NSRange(location: 0, length: (source as NSString).length)
        let result = NSMutableAttributedString(string: source, attributes: [
            .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
            .foregroundColor: NSColor.labelColor,
        ])
        for token in Syntax.tokens(in: source, format: document.format) {
            let color: NSColor
            switch token.kind {
            case .string: color = .systemGreen
            case .number: color = .systemOrange
            case .keyword: color = .systemPurple
            case .comment: color = .secondaryLabelColor
            case .key: color = .systemBlue
            }
            result.addAttribute(.foregroundColor, value: color, range: token.range)
        }
        textView.setDocument(result, regions: mode.selectedSegment == 1 ? document.foldRegions : [])
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        if full.length > 0 { textView.scrollRangeToVisible(NSRange(location: 0, length: 0)) }
    }
}
