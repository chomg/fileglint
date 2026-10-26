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
    private func controls(_ view: FoldingTextView) -> [NSButton] {
        view.enclosingScrollView?.contentView.subviews.compactMap { $0 as? NSButton } ?? []
    }
    private func accessibleContentsContain(_ view: FoldingTextView, _ control: NSButton) -> Bool {
        guard let element = NSAccessibility.unignoredDescendant(of: control) else { return false }
        return (view.enclosingScrollView?.accessibilityContents() ?? []).contains { ($0 as AnyObject) === (element as AnyObject) }
    }
    private func button(_ view: FoldingTextView, _ id: Int) throws -> NSButton {
        try #require((controls(view)).first { $0.tag == id })
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
                #expect(accessibleContentsContain(view, control))
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
            #expect((controls(view)).isEmpty)
            view.selectAll(nil); #expect(try copy(view) == raw)
            controller.mode.selectedSegment = 1; controller.updateDisplayedMode()
            #expect(view.session.collapsedIDs.isEmpty)
            controller.display(.failure(PreviewFailure.encoding))
            #expect(view.string.isEmpty && view.session.regions.isEmpty)
            #expect((controls(view)).isEmpty)
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
        #expect(!(controls(view)).contains { $0.tag == regions[2].id })
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

    @Test func disclosuresAreScrollContentsOutsideTheTextElement() throws {
        let (controller, document, window) = try show(#"{"section":{"items":[1,2]},"sibling":[3]}"#, format: .json)
        defer { window.orderOut(nil) }
        let view = controller.textView
        let scroll = try #require(view.enclosingScrollView)
        let control = try button(view, document.foldRegions[0].id)
        let accessibleControl = try #require(NSAccessibility.unignoredDescendant(of: control)) as AnyObject
        #expect(control.superview === scroll.contentView)
        let parent = try #require((accessibleControl as? any NSAccessibilityElementProtocol)?.accessibilityParent()) as AnyObject
        #expect(parent === NSAccessibility.unignoredAncestor(of: scroll) as AnyObject?)
        let center = NSPoint(x: control.bounds.midX, y: control.bounds.midY)
        #expect(scroll.contentView.hitTest(control.convert(center, to: scroll.contentView.superview)) === control)
        #expect((scroll.accessibilityContents() ?? []).contains { ($0 as AnyObject) === accessibleControl })
        #expect((view.accessibilityChildren() ?? []).isEmpty)
        #expect(view.accessibilityValue() == view.string)
        #expect(window.makeFirstResponder(control))
        control.performClick(nil)
        #expect(view.session.collapsedIDs.contains(control.tag))
        #expect(window.firstResponder === control)
        controller.mode.selectedSegment = 0; controller.updateDisplayedMode(); layout(controller)
        #expect(!scroll.contentView.subviews.contains { $0 is NSButton })
        #expect(view.string == document.raw)
    }

    @Test func nativeLayoutVirtualizesOffscreenControlsAndSupportsCursorShortcut() throws {
        let raw = "[" + Array(repeating: "[1]", count: 2_000).joined(separator: ",") + "]"
        let (controller, document, window) = try show(raw, format: .json)
        defer { window.orderOut(nil) }
        let view = controller.textView
        #expect((controls(view)).count < 100)
        // TextKit attachment objects must not duplicate the native disclosure
        // controls or expose thousands of off-screen accessibility children.
        #expect((view.enclosingScrollView?.accessibilityContents() ?? []).count < 100)
        #expect((view.accessibilityChildren() ?? []).isEmpty)
        #expect(view.accessibilityValue() == view.string)
        let last = try #require(document.foldRegions.last)
        let position = view.projection.displayOffset(forSourceOffset: last.range.location)
        view.setSelectedRange(NSRange(location: position, length: 0))
        view.scrollRangeToVisible(view.selectedRange()); layout(controller)
        #expect(view.enclosingScrollView?.contentView.bounds.intersects(try button(view, last.id).frame) == true)
        #expect((view.enclosingScrollView?.accessibilityContents() ?? []).count < 100)
        #expect((view.accessibilityChildren() ?? []).isEmpty)
        #expect(accessibleContentsContain(view, try button(view, last.id)))
        let collapse = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [.command, .option], timestamp: 0, windowNumber: window.windowNumber, context: nil, characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: 123))
        view.keyDown(with: collapse)
        #expect(view.session.collapsedIDs.contains(last.id))
        view.selectAll(nil); #expect(try copy(view) == document.pretty)
    }

    @Test func gutterKeepsExpandedSourceExactAndControlsInOneLeftColumn() throws {
        for (format, source) in [(DocumentFormat.json, #"{"section":{"items":[1,2]},"sibling":[3]}"#),
                                 (.yaml, "# heading\nsection:\n  items: [1,2]\nsibling: [3]\n"),
                                 (.toml, "[section]\nitems=[1,2]\n[sibling]\nitems=[3]\n")] {
            let (controller, document, window) = try show(source, format: format)
            defer { window.orderOut(nil) }
            let view = controller.textView
            #expect(view.string == document.pretty)
            let buttons = controls(view)
            #expect(!buttons.isEmpty)
            #expect(Set(buttons.map { $0.frame.minX }).count == 1)
            for control in buttons {
                #expect(control.frame.minX >= 0 && control.frame.maxX < view.textContainerOrigin.x)
                #expect(control.accessibilityLabel()?.contains("document ") == false)
            }
            #expect(!view.string.contains("\u{fffc}"))
            if format == .yaml {
                #expect(!view.string.contains("Mapping"))
                #expect(buttons.count == 3)
            }
            view.selectAll(nil); #expect(try copy(view) == document.pretty)
        }
    }

    @Test func gutterUsesOutermostContainerPerSourceLine() throws {
        let (controller, document, window) = try show("items: [{a: [1,2]}, [3,4]]\nsibling: [5]\n", format: .yaml)
        defer { window.orderOut(nil) }
        let view = controller.textView
        let buttons = controls(view)
        #expect(buttons.count == 2)
        let first = try #require(buttons.first { $0.accessibilityLabel()?.contains("items:") == true })
        first.performClick(nil); layout(controller)
        #expect(view.string.contains("items: [ … ]"))
        #expect(view.string.contains("sibling: [5]"))
        view.selectAll(nil); #expect(try copy(view) == document.pretty)
        first.performClick(nil); layout(controller)
        #expect(view.string == document.pretty)
    }

    @Test func gutterStaysOnFirstWrappedRowAndRejectsTextSelection() throws {
        let key = String(repeating: "long_key_", count: 18)
        let (controller, document, window) = try show("\(key): [1,2]\nnext: [3]\n", format: .yaml)
        defer { window.orderOut(nil) }
        let view = controller.textView
        let scroll = try #require(view.enclosingScrollView)
        let control = try #require(controls(view).first { $0.accessibilityLabel()?.contains("line 1:") == true })
        let x = control.frame.minX
        for width in [420.0, 800.0] {
            window.setContentSize(NSSize(width: width, height: 500)); layout(controller)
            let manager = try #require(view.layoutManager)
            let firstRow = manager.lineFragmentRect(forGlyphAt: 0, effectiveRange: nil)
            let arrayStart = (view.string as NSString).range(of: "[").location
            let arrayRow = manager.lineFragmentRect(forGlyphAt: manager.glyphIndexForCharacter(at: arrayStart), effectiveRange: nil)
            #expect(arrayRow.minY > firstRow.minY)
            #expect(abs(control.frame.minY - (firstRow.minY + view.textContainerOrigin.y)) < 1)
            #expect(control.frame.minX == x)
            #expect(Set(controls(view).map { $0.frame.minY }).count == controls(view).count)
            #expect(view.string == document.pretty)
        }
        let selection = NSRange(location: 5, length: 8)
        view.setSelectedRange(selection)
        let blank = NSPoint(x: 1, y: scroll.contentView.bounds.maxY - 2)
        let hit = try #require(scroll.contentView.hitTest(scroll.contentView.convert(blank, to: scroll.contentView.superview)))
        #expect(hit !== view && !(hit is NSButton))
        #expect(hit !== scroll.contentView && hit.superview === scroll.contentView)
        let event = try #require(NSEvent.mouseEvent(with: .leftMouseDown, location: hit.convert(.zero, to: nil), modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
        hit.mouseDown(with: event)
        #expect(view.selectedRange() == selection)
        controller.mode.selectedSegment = 0; controller.updateDisplayedMode(); layout(controller)
        #expect(view.textContainerInset.width == 14)
        #expect(hit.superview == nil)
        // Raw can have a shorter native document view than Prettified. Test
        // its left edge inside the current text area, not the old bottom point.
        let rawArea = scroll.contentView.convert(view.bounds, from: view).intersection(scroll.contentView.bounds)
        #expect(!rawArea.isEmpty)
        let rawBlank = NSPoint(x: rawArea.minX + 1, y: rawArea.midY)
        #expect(scroll.contentView.hitTest(scroll.contentView.convert(rawBlank, to: scroll.contentView.superview)) === view)
        #expect(controls(view).isEmpty)
        #expect(view.string == document.raw)
    }

    @Test func repeatedGutterActivationKeepsTheSameFocusedButton() throws {
        let source = "settings:\n  nested:\n    items: [1,2,3]\nsibling:\n  nested:\n    items: [4,5]\nlast:\n  value: true\n"
        let (controller, document, window) = try show(source, format: .yaml)
        defer { window.orderOut(nil) }
        let view = controller.textView
        let ids = controls(view).map(\.tag)
        for id in ids {
            let control = try button(view, id)
            let accessible = try #require(NSAccessibility.unignoredDescendant(of: control)) as AnyObject
            #expect(window.makeFirstResponder(control))
            for iteration in 0..<6 {
                control.performClick(nil)
                layout(controller)
                RunLoop.current.run(until: Date().addingTimeInterval(0.02))
                #expect((try button(view, id)) === control)
                #expect(NSAccessibility.unignoredDescendant(of: control) as AnyObject? === accessible)
                #expect(window.firstResponder === control)
                #expect(view.session.collapsedIDs.contains(id) == (iteration % 2 == 0))
            }
            #expect(view.string == document.pretty)
        }
    }

    @Test func twoImmediateNativeActionsRestoreTheExpandedDocument() throws {
        let (controller, document, window) = try show("settings:\n  nested:\n    items: [1,2,3]\nsibling: [4]\n", format: .yaml)
        defer { window.orderOut(nil) }
        let view = controller.textView
        let control = try #require(controls(view).first { $0.accessibilityLabel()?.contains("settings:") == true })
        let action = try #require(control.action)
        #expect(window.makeFirstResponder(control))
        for _ in 0..<10 {
            // No sleep, animation, layout pass or event-loop turn between the
            // actions: two activations must toggle twice, ending where they began.
            #expect(control.sendAction(action, to: control.target))
            #expect(view.session.collapsedIDs.contains(control.tag))
            #expect(view.string.contains("…"))
            #expect(control.sendAction(action, to: control.target))
            #expect(view.session.collapsedIDs.isEmpty)
            #expect(view.string == document.pretty)
            #expect(window.firstResponder === control)
        }
        view.selectAll(nil); #expect(try copy(view) == document.pretty)
    }
}
}
