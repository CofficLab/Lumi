import XCTest

final class LumiUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        app.activate()
    }

    func testMainWindowShowsRootContent() {
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 20))

        let rootContent = app.descendants(matching: .any)
            .matching(identifier: "root.main")
            .firstMatch
        XCTAssertTrue(rootContent.waitForExistence(timeout: 20))
    }
}
