import XCTest
import AppKit

final class HostUITests: XCTestCase {
    func testSetupSampleAndModeSwitching() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.windows["Fileglint"].buttons["try-sample"].waitForExistence(timeout: 10))
        app.buttons["try-sample"].click()
        let window = app.windows["Sample Preview"]
        XCTAssertTrue(window.waitForExistence(timeout: 5))
        XCTAssertFalse(window.buttons["open-default-application"].isHittable)
        XCTAssertFalse(window.buttons["choose-application"].isHittable)
        let content = window.textViews["preview-content"]
        XCTAssertTrue(content.waitForExistence(timeout: 5))
        XCTAssertTrue((content.value as? String)?.contains("Fileglint") == true)
        window.radioButtons["Prettified"].click()
        XCTAssertTrue((content.value as? String)?.contains("\n") == true)
        window.radioButtons["Raw"].click()
        XCTAssertFalse((content.value as? String)?.contains("\n") == true)
        content.click()
        content.typeKey("a", modifierFlags: .command)
        content.typeKey("c", modifierFlags: .command)
        XCTAssertEqual(NSPasteboard.general.string(forType: .string), #"{"name":"Fileglint","enabled":true,"items":[1,2,3]}"#)
        app.terminate()
    }

    func testYAMLAndTOMLSamplesPreserveComments() throws {
        let app = XCUIApplication()
        app.launch()
        defer { app.terminate() }
        let picker = app.popUpButtons["sample-format"]
        XCTAssertTrue(picker.waitForExistence(timeout: 10))
        for format in ["YAML", "TOML"] {
            picker.click()
            app.menuItems[format].click()
            app.buttons["try-sample"].click()
            let window = app.windows["Sample Preview"]
            let content = window.textViews["preview-content"]
            XCTAssertTrue(content.waitForExistence(timeout: 5))
            XCTAssertFalse(window.buttons["choose-application"].isHittable)
            let raw = try XCTUnwrap(content.value as? String)
            window.radioButtons["Prettified"].click()
            let formatted = try XCTUnwrap(content.value as? String)
            XCTAssertTrue(formatted.hasPrefix("# Fileglint settings\n"))
            XCTAssertTrue(formatted.contains("# application name\n"))
            XCTAssertTrue(formatted.contains("[1, 2, 3] # sample values"), formatted)
            content.click()
            content.typeKey("a", modifierFlags: .command)
            content.typeKey("c", modifierFlags: .command)
            let expected = format == "YAML"
                ? "# Fileglint settings\nname: Fileglint # application name\nitems: [1, 2, 3] # sample values\npreview:\n  # display settings\n  enabled: true\n  nested:\n    values: [4, 5]\n"
                : "# Fileglint settings\nname = \"Fileglint\" # application name\nitems = [1, 2, 3] # sample values\n\n# display settings\n[preview]\nenabled = true\n[preview.nested]\nvalues = [4, 5]\n"
            XCTAssertEqual(formatted, expected)
            XCTAssertEqual(NSPasteboard.general.string(forType: .string), expected)
            window.radioButtons["Raw"].click()
            XCTAssertEqual(content.value as? String, raw)
            window.buttons[XCUIIdentifierCloseWindow].click()
        }
    }

    func testPrettifiedFoldingCopiesHiddenContentAndResets() throws {
        let app = XCUIApplication()
        app.launch()
        defer { app.terminate() }
        let picker = app.popUpButtons["sample-format"]
        XCTAssertTrue(picker.waitForExistence(timeout: 10))
        for format in ["JSON", "YAML", "TOML"] {
            picker.click(); app.menuItems[format].click()
            app.buttons["try-sample"].click()
            let window = app.windows["Sample Preview"]
            let content = window.textViews["preview-content"]
            XCTAssertTrue(content.waitForExistence(timeout: 5))
            let raw = try XCTUnwrap(content.value as? String)
            window.radioButtons["Prettified"].click()
            let controls = window.descendants(matching: .button).matching(NSPredicate(format: "identifier BEGINSWITH %@", "fold-"))
            XCTAssertTrue(controls.firstMatch.waitForExistence(timeout: 5))
            let expanded = try XCTUnwrap(content.value as? String)
            for button in controls.allElementsBoundByIndex {
                XCTAssertLessThan(button.frame.maxX, content.frame.minX + 32)
            }
            content.click(); content.typeKey("a", modifierFlags: .command); content.typeKey("c", modifierFlags: .command)
            let full = try XCTUnwrap(NSPasteboard.general.string(forType: .string))
            XCTAssertEqual(expanded, full)
            XCTAssertFalse(full.contains("\u{fffc}"))
            let id = controls.firstMatch.identifier
            window.buttons[id].click()
            XCTAssertTrue((content.value as? String)?.contains("…") == true)
            XCTAssertTrue(window.buttons[id].label.hasPrefix("Expand"))
            content.click(); content.typeKey("a", modifierFlags: .command); content.typeKey("c", modifierFlags: .command)
            XCTAssertEqual(NSPasteboard.general.string(forType: .string), full)
            window.buttons[id].click()
            XCTAssertTrue(window.buttons[id].label.hasPrefix("Collapse"))
            window.radioButtons["Raw"].click()
            XCTAssertFalse(controls.firstMatch.exists)
            XCTAssertEqual(content.value as? String, raw)
            window.radioButtons["Prettified"].click()
            XCTAssertTrue(window.buttons[id].label.hasPrefix("Collapse"))
            window.buttons[XCUIIdentifierCloseWindow].click()
        }
    }
}
