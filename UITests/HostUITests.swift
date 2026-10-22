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
}
