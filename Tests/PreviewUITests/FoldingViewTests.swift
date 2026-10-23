import AppKit
import Testing
import PreviewCore
@testable import PreviewUI

extension AppKitTests {
@Suite(.serialized) @MainActor
struct FoldingViewTests {
    private func show(_ source: String, format: DocumentFormat) throws -> (PreviewViewController, PreviewDocument, NSWindow) {
        _ = NSApplication.shared
        let controller = PreviewViewController()
        let document = try PreviewDocument(data: Data(source.utf8), format: format)
        try #require(document.pretty != nil)
        controller.display(.success(document))
        let window = NSWindow(contentViewController: controller)
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 800, height: 500))
        // Component geometry does not require taking the user's key window.
        controller.mode.selectedSegment = 1
        controller.updateDisplayedMode()
        layout(controller)
        return (controller, document, window)
    }
    private func layout(_ controller: PreviewViewController) {
        controller.view.layoutSubtreeIfNeeded()
        if let container = controller.textView.textContainer { controller.textView.layoutManager?.ensureLayout(for: container) }
        controller.textView.layoutSubtreeIfNeeded()
    }
    private func button(_ view: FoldingTextView, _ id: Int) throws -> NSButton {
        try #require(view.subviews.compactMap { $0 as? NSButton }.first { $0.tag == id })
    }
    private func copy(_ view: FoldingTextView) throws -> String {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        #expect(view.writeSelection(to: board, types: [.string]))
        return try #require(board.string(forType: .string))
    }
    private func capture(_ controller: PreviewViewController, name: String) throws {
        guard ProcessInfo.processInfo.environment["FILEGLINT_CAPTURE_FOLDING"] == "1" else { return }
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let directory = root.appendingPathComponent("artifacts/issue2-visuals")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let view = controller.view
        let image = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.effectiveAppearance.performAsCurrentDrawingAppearance { view.cacheDisplay(in: view.bounds, to: image) }
        try #require(image.representation(using: .png, properties: [:])).write(to: directory.appendingPathComponent(name + ".png"))
    }

    @Test func nativeDisclosureCopyColorAndModeResetForEveryFormat() throws {
        let cases: [(DocumentFormat, String)] = [
            (.json, #"{"section":{"items":[1,2]},"sibling":[3]}"#),
            (.yaml, "# heading\nsection:\n  # interior\n  items: [1,2]\nsibling: [3]\n"),
            (.toml, "# heading\n[section]\n# interior\nitems=[1,2]\n[sibling]\nitems=[3]\n"),
        ]
        for (format, raw) in cases {
            let (controller, document, window) = try show(raw, format: format)
            defer { window.orderOut(nil) }
            let view = controller.textView
            let region = try #require(document.foldRegions.first)
            for name in [NSAppearance.Name.aqua, .darkAqua] {
                controller.view.appearance = NSAppearance(named: name)
                let control = try button(view, region.id)
                try capture(controller, name: "\(format.rawValue)-\(name.rawValue)-expanded")
                #expect(control.isAccessibilityExpanded())
                #expect((view.accessibilityChildren() ?? []).contains { ($0 as? NSButton) === control })
                #expect(control.accessibilityLabel()?.hasPrefix("Collapse") == true)
                control.performClick(nil)
                layout(controller)
                #expect(view.session.collapsedIDs.contains(region.id))
                #expect(!control.isAccessibilityExpanded())
                #expect(control.accessibilityLabel()?.hasPrefix("Expand") == true)
                #expect(view.string.contains("…"))
                try capture(controller, name: "\(format.rawValue)-\(name.rawValue)-collapsed")
                view.selectAll(nil)
                #expect(try copy(view) == document.pretty)
                control.performClick(nil)
                layout(controller)
                #expect(view.session.collapsedIDs.isEmpty)
                view.selectAll(nil)
                #expect(try copy(view) == document.pretty)
                if format != .json {
                    let comment = (view.string as NSString).range(of: "# interior")
                    #expect(comment.location != NSNotFound)
                    #expect(view.textStorage?.attribute(.foregroundColor, at: comment.location, effectiveRange: nil) as? NSColor == .secondaryLabelColor)
                }
            }
            controller.mode.selectedSegment = 0; controller.updateDisplayedMode(); layout(controller)
            #expect(view.string == raw)
            #expect(view.session.regions.isEmpty)
            #expect(view.subviews.compactMap { $0 as? NSButton }.isEmpty)
            view.selectAll(nil); #expect(try copy(view) == raw)
            controller.mode.selectedSegment = 1; controller.updateDisplayedMode()
            #expect(view.session.collapsedIDs.isEmpty)
            controller.display(.failure(PreviewFailure.encoding))
            #expect(view.string.isEmpty && view.session.regions.isEmpty)
            #expect(view.subviews.compactMap { $0 as? NSButton }.isEmpty)
        }
    }

    @Test func nativeParentToggleRetainsChildAndPartialCopyUsesHiddenContent() throws {
        let (controller, document, window) = try show(#"{"a":{"child":[1,2]},"b":[3]}"#, format: .json)
        defer { window.orderOut(nil) }
        let view = controller.textView, regions = document.foldRegions
        let oldRoot = try button(view, regions[0].id)
        try button(view, regions[2].id).performClick(nil)
        #expect(controller.mode.sendAction(controller.mode.action!, to: controller.mode.target))
        #expect(view.session.collapsedIDs == [regions[2].id])
        try button(view, regions[1].id).performClick(nil)
        layout(controller)
        #expect(view.session.collapsedIDs == [regions[1].id, regions[2].id])
        #expect(!view.subviews.compactMap { $0 as? NSButton }.contains { $0.tag == regions[2].id })
        try button(view, regions[1].id).performClick(nil); layout(controller)
        #expect(view.session.collapsedIDs == [regions[2].id])
        #expect(!(try button(view, regions[2].id)).isAccessibilityExpanded())
        let source = document.pretty! as NSString
        let start = source.range(of: "\"a\"").location
        let end = source.range(of: "\"b\"").location
        let from = view.projection.displayOffset(forSourceOffset: start), to = view.projection.displayOffset(forSourceOffset: end)
        view.setSelectedRange(NSRange(from..<to))
        #expect(try copy(view) == source.substring(with: NSRange(start..<end)))
        let another = try PreviewDocument(data: Data("[1]".utf8), format: .json)
        controller.display(.success(another)); layout(controller)
        #expect(view.session.regions.isEmpty && view.string == "[1]")
        controller.mode.selectedSegment = 1; controller.updateDisplayedMode(); layout(controller)
        #expect(view.session.regions == another.foldRegions && view.session.collapsedIDs.isEmpty)
        oldRoot.performClick(nil)
        #expect(view.session.collapsedIDs.isEmpty)
    }

    @Test func nativeLayoutVirtualizesOffscreenControlsAndSupportsCursorShortcut() throws {
        let raw = "[" + Array(repeating: "[1]", count: 2_000).joined(separator: ",") + "]"
        let (controller, document, window) = try show(raw, format: .json)
        defer { window.orderOut(nil) }
        let view = controller.textView
        #expect(view.subviews.compactMap { $0 as? NSButton }.count < 100)
        let last = try #require(document.foldRegions.last)
        let position = view.projection.displayOffset(forSourceOffset: last.range.location)
        view.setSelectedRange(NSRange(location: position, length: 0))
        view.scrollRangeToVisible(view.selectedRange()); layout(controller)
        #expect((try button(view, last.id)).frame.maxY <= view.bounds.maxY + 20)
        let collapse = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [.command, .option], timestamp: 0, windowNumber: window.windowNumber, context: nil, characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: 123))
        view.keyDown(with: collapse)
        #expect(view.session.collapsedIDs.contains(last.id))
        view.selectAll(nil); #expect(try copy(view) == document.pretty)
    }
}
}
