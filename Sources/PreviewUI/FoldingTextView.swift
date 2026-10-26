import AppKit
import PreviewCore

/// A non-selectable margin. Buttons remain independent peers so native
/// accessibility and Full Keyboard Access see them outside the text element.
private final class FoldingGutter: NSView {
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.intersection(dirtyRect)
        NSColor.controlBackgroundColor.setFill(); rect.fill()
        NSColor.separatorColor.setFill()
        NSRect(x: bounds.maxX - 1, y: rect.minY, width: 1, height: rect.height).fill()
    }
    override func mouseDown(with event: NSEvent) {}
    override func mouseDragged(with event: NSEvent) {}
}

/// Expose controls beside the text accessibility element so motor navigation
/// can discover each disclosure independently of text interaction.
@MainActor
final class FoldingScrollView: NSScrollView {
    static let gutterWidth: CGFloat = 28
    private let gutter = FoldingGutter()

    func updateGutter(shown: Bool) {
        guard shown else { gutter.removeFromSuperview(); return }
        if gutter.superview !== contentView { contentView.addSubview(gutter, positioned: .above, relativeTo: documentView) }
        gutter.frame = NSRect(x: contentView.bounds.minX, y: contentView.bounds.minY,
                              width: Self.gutterWidth, height: contentView.bounds.height)
    }

    override func accessibilityContents() -> [Any]? {
        guard let documentView else { return [] }
        let buttons = (documentView as? FoldingTextView)?.disclosureControls.filter {
            $0.frame.intersects(contentView.bounds)
        } ?? []
        return NSAccessibility.unignoredChildren(from: [documentView] + buttons)
    }

    override func accessibilityChildren() -> [Any]? {
        let scrollers: [NSView] = [hasVerticalScroller ? verticalScroller : nil, hasHorizontalScroller ? horizontalScroller : nil].compactMap { $0 }
        return (accessibilityContents() ?? []) + NSAccessibility.unignoredChildren(from: scrollers)
    }

    override func accessibilityChildrenInNavigationOrder() -> [any NSAccessibilityElementProtocol]? {
        accessibilityChildren()?.compactMap { $0 as? any NSAccessibilityElementProtocol }
    }
}

@MainActor
public final class FoldingTextView: NSTextView {
    public private(set) var session = FoldSession(regions: [])
    public private(set) var projection = FoldProjection(source: "", session: FoldSession(regions: []))
    private var original = NSAttributedString(string: "")
    private var regionsByID = [Int: FoldRegion]()
    private var disclosureButtons = [Int: NSButton]()
    private var accessibleFrames = [ObjectIdentifier: NSRect]()
    private var clipObserver: NSObjectProtocol?
    private var updatingButtons = false
    private var updatingPresentation = false
    private var showsGutter = false
    private var lineStarts = [0]
    private var lineLabels = [Int: String]()
    public weak var afterDisclosures: NSView?

    public func setDocument(_ text: NSAttributedString, regions: [FoldRegion], showsGutter: Bool = false) {
        self.showsGutter = showsGutter
        textContainerInset = NSSize(width: 14 + (showsGutter ? FoldingScrollView.gutterWidth : 0), height: 14)
        for button in disclosureButtons.values { button.removeFromSuperview() }
        disclosureButtons.removeAll()
        original = NSAttributedString(attributedString: text)
        lineStarts = [0]; lineLabels.removeAll()
        let units = Array(text.string.utf16)
        for (offset, unit) in units.enumerated() {
            if unit == 10 || unit == 0x85 || unit == 0x2028 || unit == 0x2029 || (unit == 13 && (offset + 1 == units.count || units[offset + 1] != 10)) { lineStarts.append(offset + 1) }
        }
        session = FoldSession(regions: regions)
        regionsByID = Dictionary(uniqueKeysWithValues: regions.map { ($0.id, $0) })
        render()
        setSelectedRange(NSRange(location: 0, length: 0))
    }

    public func toggleFold(_ id: Int) {
        guard regionsByID[id] != nil else { return }
        let viewport = enclosingScrollView?.contentView.bounds.origin
        let selection = selectedRange()
        let from = projection.sourceOffset(forDisplayOffset: selection.location)
        let to = selection.length == 0 ? from : projection.sourceOffset(forDisplayOffset: NSMaxRange(selection), trailing: true)
        // Text replacement, selection remapping and viewport restoration can
        // each trigger layout. Keep the native controls stable until the final
        // geometry is ready, then notify accessibility clients once.
        updatingPresentation = true
        session.toggle(id)
        render()
        let start = projection.displayOffset(forSourceOffset: from)
        let end = projection.displayOffset(forSourceOffset: to, trailing: true)
        setSelectedRange(NSRange(location: start, length: max(0, end - start)))
        if let viewport, let scroll = enclosingScrollView { scroll.contentView.scroll(to: viewport); scroll.reflectScrolledClipView(scroll.contentView) }
        updatingPresentation = false
        updateDisclosureButtons(changedID: id)
    }

    private func render() {
        projection = FoldProjection(source: original.string, session: session)
        let result = NSMutableAttributedString(string: "")
        for segment in projection.segments {
            switch segment.kind {
            case .source: result.append(original.attributedSubstring(from: segment.sourceRange))
            case .placeholder:
                result.append(NSAttributedString(string: (projection.string as NSString).substring(with: segment.displayRange), attributes: [
                    .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
                    .foregroundColor: NSColor.secondaryLabelColor,
                    .toolTip: "Hidden text is included when copied.",
                ]))
            }
        }
        textStorage?.setAttributedString(result)
        needsLayout = true
        updateDisclosureButtons()
    }

    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let clipObserver { NotificationCenter.default.removeObserver(clipObserver); self.clipObserver = nil }
        if let clip = enclosingScrollView?.contentView {
            clip.postsBoundsChangedNotifications = true
            clipObserver = NotificationCenter.default.addObserver(forName: NSView.boundsDidChangeNotification, object: clip, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.updateDisclosureButtons() }
            }
        }
        updateDisclosureButtons()
    }
    deinit { if let clipObserver { NotificationCenter.default.removeObserver(clipObserver) } }

    public override func layout() { super.layout(); updateDisclosureButtons() }

    public override func accessibilityChildren() -> [Any]? {
        // The gutter buttons are independent peers, outside this atomic text
        // accessibility element. The inherited text/selection stays native.
        []
    }

    var disclosureControls: [NSButton] {
        disclosureButtons.values.sorted {
            $0.frame.minY == $1.frame.minY ? $0.frame.minX < $1.frame.minX : $0.frame.minY < $1.frame.minY
        }
    }

    private func updateDisclosureButtons(changedID: Int? = nil) {
        guard !updatingButtons, !updatingPresentation else { return }
        updatingButtons = true
        defer {
            updatingButtons = false
            let frames = Dictionary(uniqueKeysWithValues: disclosureButtons.values.map { (ObjectIdentifier($0), $0.frame) })
            if let changedID, let button = disclosureButtons[changedID] {
                NSAccessibility.post(element: NSAccessibility.unignoredDescendant(of: button) ?? button, notification: .valueChanged)
            }
            if frames != accessibleFrames || changedID != nil {
                accessibleFrames = frames
                let changed = changedID.flatMap { disclosureButtons[$0] }.map { [$0] } ?? disclosureControls
                NSAccessibility.post(element: enclosingScrollView ?? self, notification: .layoutChanged,
                                     userInfo: [.uiElements: NSAccessibility.unignoredChildren(from: changed)])
            }
        }
        (enclosingScrollView as? FoldingScrollView)?.updateGutter(shown: showsGutter)
        guard showsGutter, !projection.controls.isEmpty, let manager = layoutManager, let container = textContainer,
              let buttonHost = enclosingScrollView?.contentView else {
            for button in disclosureButtons.values { button.removeFromSuperview() }
            disclosureButtons.removeAll(); nextKeyView = afterDisclosures
            return
        }
        let viewport = visibleRect.insetBy(dx: -30, dy: -50)
        let glyphs = manager.glyphRange(forBoundingRect: viewport.offsetBy(dx: -textContainerInset.width, dy: -textContainerInset.height), in: container)
        let characters = manager.characterRange(forGlyphRange: glyphs, actualGlyphRange: nil)
        var visible = Set<Int>(), ordered = [NSButton](), rows = Set<CGFloat>()
        // Binary search to avoid scanning thousands of off-screen controls on
        // each scroll. Only viewport controls receive native button views.
        let controls = projection.controls
        var low = 0, high = controls.count
        while low < high { let mid = (low + high) / 2; if controls[mid].displayOffset < characters.location { low = mid + 1 } else { high = mid } }
        for control in controls.dropFirst(low) {
            guard control.displayOffset <= NSMaxRange(characters) else { break }
            let id = control.id
            guard let region = regionsByID[id], control.displayOffset < (string as NSString).length else { continue }
            let glyph = manager.glyphIndexForCharacter(at: control.displayOffset)
            let rect = manager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil).offsetBy(dx: textContainerOrigin.x, dy: textContainerOrigin.y)
            guard rect.intersects(viewport), rows.insert(rect.minY).inserted else { continue }
            let button = disclosureButtons[id] ?? NSButton()
            if button.superview !== buttonHost { buttonHost.addSubview(button, positioned: .above, relativeTo: nil) }
            let line = convert(rect, to: buttonHost)
            button.frame = NSRect(x: buttonHost.bounds.minX + 4, y: line.minY, width: 19, height: max(14, line.height))
            let collapsed = session.collapsedIDs.contains(id)
            button.image = NSImage(systemSymbolName: collapsed ? "chevron.right" : "chevron.down", accessibilityDescription: nil)
            button.isBordered = false
            button.focusRingType = .exterior
            button.imagePosition = .imageOnly
            button.contentTintColor = .secondaryLabelColor
            button.target = self; button.action = #selector(toggleDisclosure(_:)); button.tag = id
            button.setAccessibilityIdentifier("fold-\(id)")
            let label = heading(for: region)
            button.setAccessibilityLabel("\(collapsed ? "Expand" : "Collapse") \(label)")
            button.setAccessibilityExpanded(!collapsed)
            button.setAccessibilityValue(NSNumber(value: !collapsed))
            button.toolTip = "\(collapsed ? "Expand" : "Collapse") \(label). ⌘⌥← collapses; ⌘⌥→ expands the section at the text cursor."
            disclosureButtons[id] = button
            visible.insert(id); ordered.append(button)
        }
        for id in disclosureButtons.keys.filter({ !visible.contains($0) }) {
            guard let button = disclosureButtons[id] else { continue }
            button.removeFromSuperview(); disclosureButtons.removeValue(forKey: id)
        }
        nextKeyView = ordered.first ?? afterDisclosures
        for (index, button) in ordered.enumerated() { button.nextKeyView = index + 1 < ordered.count ? ordered[index + 1] : afterDisclosures }
    }

    private func heading(for region: FoldRegion) -> String {
        let source = original.string as NSString
        var low = 0, high = lineStarts.count
        while low < high { let mid = (low + high) / 2; if lineStarts[mid] <= region.range.location { low = mid + 1 } else { high = mid } }
        let index = max(0, low - 1)
        if lineLabels[index] == nil {
            let end = index + 1 < lineStarts.count ? lineStarts[index + 1] : source.length
            let snippet = source.substring(with: NSRange(location: lineStarts[index], length: min(256, end - lineStarts[index])))
            lineLabels[index] = String(snippet.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
        }
        let kind = region.kind == .tableEntry ? "table entry" : region.kind.rawValue
        return "\(kind) at line \(index + 1): \(lineLabels[index] ?? "")"
    }
    @objc private func toggleDisclosure(_ sender: NSButton) {
        // A queued action from a removed document/viewport button must not
        // target a new section that happens to have the same source offset.
        guard disclosureButtons[sender.tag] === sender else { return }
        toggleFold(sender.tag)
    }

    public override var writablePasteboardTypes: [NSPasteboard.PasteboardType] { [.string] }
    public override func writeSelection(to pasteboard: NSPasteboard, types: [NSPasteboard.PasteboardType]) -> Bool {
        guard types.contains(.string) else { return false }
        let content = selectedRanges.map { projection.copiedText(in: $0.rangeValue) }.joined(separator: "\n")
        guard selectedRanges.contains(where: { $0.rangeValue.length > 0 }) else { return false }
        pasteboard.declareTypes([.string], owner: nil)
        return pasteboard.setString(content, forType: .string)
    }

    public override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags == [.command, .option] && (event.keyCode == 123 || event.keyCode == 124) {
            let cursor = selectedRange().location
            let sourceCursor = projection.sourceOffset(forDisplayOffset: cursor)
            let actionable = Set(projection.controls.map(\.id))
            let candidates = session.visibleRegions.filter { region in
                guard actionable.contains(region.id) else { return false }
                return sourceCursor >= region.range.location && sourceCursor <= NSMaxRange(region.range)
            }
            if let region = candidates.min(by: { $0.range.length == $1.range.length ? $0.depth > $1.depth : $0.range.length < $1.range.length }) {
                let collapse = event.keyCode == 123
                if session.collapsedIDs.contains(region.id) != collapse { toggleFold(region.id) }
                return
            }
        }
        super.keyDown(with: event)
    }
}
