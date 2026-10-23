import AppKit
import PreviewCore

private final class DisclosureSpace: NSTextAttachmentCell {
    override func cellSize() -> NSSize { NSSize(width: 20, height: 17) }
    override func cellBaselineOffset() -> NSPoint { NSPoint(x: 0, y: -3) }
    override func draw(withFrame cellFrame: NSRect, in controlView: NSView?) {}
}

@MainActor
public final class FoldingTextView: NSTextView {
    public private(set) var session = FoldSession(regions: [])
    public private(set) var projection = FoldProjection(source: "", session: FoldSession(regions: []))
    private var original = NSAttributedString(string: "")
    private var regionsByID = [Int: FoldRegion]()
    private var disclosureButtons = [Int: NSButton]()
    private var clipObserver: NSObjectProtocol?
    private var updatingButtons = false
    private var lineStarts = [0]
    private var lineLabels = [Int: String]()
    public weak var afterDisclosures: NSView?

    public func setDocument(_ text: NSAttributedString, regions: [FoldRegion]) {
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
        session.toggle(id)
        render()
        let start = projection.displayOffset(forSourceOffset: from)
        let end = projection.displayOffset(forSourceOffset: to, trailing: true)
        setSelectedRange(NSRange(location: start, length: max(0, end - start)))
        if let viewport, let scroll = enclosingScrollView { scroll.contentView.scroll(to: viewport); scroll.reflectScrolledClipView(scroll.contentView) }
    }

    private func render() {
        projection = FoldProjection(source: original.string, session: session)
        let result = NSMutableAttributedString(string: "")
        for segment in projection.segments {
            switch segment.kind {
            case .source: result.append(original.attributedSubstring(from: segment.sourceRange))
            case .control:
                let attachment = NSTextAttachment()
                attachment.attachmentCell = DisclosureSpace(textCell: "")
                result.append(NSAttributedString(attachment: attachment))
            case .placeholder, .annotation:
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
        // TextKit exposes every attachment as an additional AXUnknown child,
        // including off-screen arrows. These are presentation-only spaces;
        // expose each visible native button once. The text view keeps its
        // inherited accessible text value, selection and range operations.
        return disclosureButtons.values.sorted {
            $0.frame.minY == $1.frame.minY ? $0.frame.minX < $1.frame.minX : $0.frame.minY < $1.frame.minY
        }
    }

    private func updateDisclosureButtons() {
        guard !updatingButtons else { return }
        updatingButtons = true
        defer { updatingButtons = false }
        guard !projection.controls.isEmpty, let manager = layoutManager, let container = textContainer else {
            for button in disclosureButtons.values { button.removeFromSuperview() }
            disclosureButtons.removeAll(); nextKeyView = afterDisclosures
            return
        }
        let viewport = visibleRect.insetBy(dx: -30, dy: -50)
        let glyphs = manager.glyphRange(forBoundingRect: viewport.offsetBy(dx: -textContainerInset.width, dy: -textContainerInset.height), in: container)
        let characters = manager.characterRange(forGlyphRange: glyphs, actualGlyphRange: nil)
        var visible = Set<Int>(), ordered = [NSButton]()
        // Binary search to avoid scanning thousands of off-screen controls on
        // each scroll. Only viewport controls receive native button views.
        let controls = projection.controls
        var low = 0, high = controls.count
        while low < high { let mid = (low + high) / 2; if controls[mid].displayRange.location < characters.location { low = mid + 1 } else { high = mid } }
        for segment in controls.dropFirst(low) {
            guard segment.displayRange.location <= NSMaxRange(characters) else { break }
            guard case .control(let id) = segment.kind, let region = regionsByID[id] else { continue }
            let range = manager.glyphRange(forCharacterRange: segment.displayRange, actualCharacterRange: nil)
            let rect = manager.boundingRect(forGlyphRange: range, in: container).offsetBy(dx: textContainerInset.width, dy: textContainerInset.height)
            guard rect.intersects(viewport) else { continue }
            let button = disclosureButtons[id] ?? NSButton()
            if button.superview == nil { addSubview(button) }
            button.frame = NSRect(x: rect.minX, y: rect.minY, width: 19, height: max(17, rect.height))
            let collapsed = session.collapsedIDs.contains(id)
            button.image = NSImage(systemSymbolName: collapsed ? "chevron.right" : "chevron.down", accessibilityDescription: nil)
            button.isBordered = false
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
        if region.depth == 0 && region.range == region.contentRange { return "document \(kind) at line \(index + 1)" }
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
            let candidates = session.visibleRegions.filter { region in
                sourceCursor >= region.range.location && sourceCursor <= NSMaxRange(region.range)
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
