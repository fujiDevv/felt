import XCTest

@MainActor
final class FeltUITests: XCTestCase {
    func testMenuAndWorldPreview() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--show-menu", "--light-appearance"]
        app.launch()
        let cloth = app.buttons["Cloth sound world"]
        XCTAssertTrue(cloth.waitForExistence(timeout: 10), "Felt opens its menu bar popover")
        XCTAssertTrue(app.sliders["Volume"].exists)
        cloth.click()
        XCTAssertTrue(app.staticTexts["Soft as a whisper."].waitForExistence(timeout: 3))
        app.buttons["Paper sound world"].click()
        XCTAssertTrue(app.staticTexts["Airy little touches."].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Preview sound"].exists)
        let more = app.menuButtons["More options"]
        if !more.isHittable { app.scrollViews.firstMatch.swipeUp() }
        XCTAssertTrue(more.isHittable, "Footer controls are reachable inside the popover")
        let content = app.descendants(matching: .any).matching(identifier: "Felt content").firstMatch
        let screenshot = XCTAttachment(screenshot: content.screenshot())
        screenshot.name = "Felt light appearance"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.radioButtons["Settings"].click()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "Quiet on calls").firstMatch.isHittable)
        XCTAssertTrue(app.staticTexts["Gestures"].exists)
        app.terminate()
    }

    func testDarkAppearance() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--show-menu", "--dark-appearance"]
        app.launch()
        XCTAssertTrue(app.buttons["Paper sound world"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Preview sound"].isHittable)
        XCTAssertTrue(app.sliders["Volume"].isHittable)
        let content = app.descendants(matching: .any).matching(identifier: "Felt content").firstMatch
        let screenshot = XCTAttachment(screenshot: content.screenshot())
        screenshot.name = "Felt dark appearance"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.terminate()
    }
}
