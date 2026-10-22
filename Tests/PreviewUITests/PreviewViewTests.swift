import AppKit
import Testing
import PreviewCore
@testable import PreviewUI

struct PreviewViewTests {
    @Test @MainActor func testRealControlsSwitchAndClearStaleContent() throws {
        _ = NSApplication.shared
        let controller = PreviewViewController()
        let raw = #"{"message":"세계","n":42}"#
        let document = try PreviewDocument(data: Data(raw.utf8), format: .json)
        controller.display(.success(document))
        #expect(controller.textView.string == raw)
        #expect(!(controller.textView.isEditable))
        #expect(controller.textView.isSelectable)
        #expect(controller.mode.isEnabled(forSegment: 1))
        controller.mode.selectedSegment = 1
        #expect(controller.mode.sendAction(controller.mode.action!, to: controller.mode.target))
        #expect(controller.textView.string == document.pretty)
        controller.mode.selectedSegment = 0
        #expect(controller.mode.sendAction(controller.mode.action!, to: controller.mode.target))
        #expect(controller.textView.string == raw)
        #expect(controller.textView.textStorage?.attribute(.foregroundColor, at: 3, effectiveRange: nil) as? NSColor == .systemGreen)
        controller.display(.failure(PreviewFailure.encoding))
        #expect(controller.textView.string == "")
        #expect(!(controller.mode.isEnabled(forSegment: 1)))
        #expect(controller.status.stringValue.contains("UTF-8"))
    }

    @Test @MainActor func testMalformedInputVisibleInBothAppearances() throws {
        _ = NSApplication.shared
        let controller = PreviewViewController()
        let invalid = try PreviewDocument(data: Data("{".utf8), format: .json)
        for name in [NSAppearance.Name.aqua, .darkAqua] {
            controller.view.appearance = NSAppearance(named: name)
            controller.display(.success(invalid))
            #expect(controller.textView.string == "{")
            #expect(!(controller.mode.isEnabled(forSegment: 1)))
            #expect(controller.status.stringValue.contains("Cannot prettify"))
        }
    }

    @Test @MainActor func testCommentsRemainVisibleColoredAndCopied() throws {
        _ = NSApplication.shared
        let controller = PreviewViewController()
        for format in [DocumentFormat.yaml, .toml] {
            let raw = format == .yaml ? "\u{feff}# heading\r\nitems: [1,2] # note\r\n" : "\u{feff}# heading\r\nitems=[1,2] # note\r\n"
            let document = try PreviewDocument(data: Data(raw.utf8), format: format)
            for appearance in [NSAppearance.Name.aqua, .darkAqua] {
                controller.view.appearance = NSAppearance(named: appearance)
                controller.display(.success(document))
                controller.mode.selectedSegment = 1
                #expect(controller.mode.sendAction(controller.mode.action!, to: controller.mode.target))
                let formatted = try #require(document.pretty)
                #expect(controller.textView.string == formatted)
                #expect(controller.textView.isSelectable && !controller.textView.isEditable)
                let comment = (formatted as NSString).range(of: "# note")
                #expect(controller.textView.textStorage?.attribute(.foregroundColor, at: comment.location, effectiveRange: nil) as? NSColor == .secondaryLabelColor)
                #expect(controller.status.stringValue.contains("preserves comments"))
                let pasteboard = NSPasteboard.withUniqueName()
                defer { pasteboard.releaseGlobally() }
                controller.textView.setSelectedRange(NSRange(location: 0, length: (formatted as NSString).length))
                let types = controller.textView.writablePasteboardTypes
                #expect(!types.isEmpty)
                #expect(controller.textView.writeSelection(to: pasteboard, types: types))
                #expect(pasteboard.string(forType: .string) == formatted)
                controller.mode.selectedSegment = 0
                #expect(controller.mode.sendAction(controller.mode.action!, to: controller.mode.target))
                #expect(controller.textView.string == raw)
            }
        }
    }
}
