#if canImport(XCTest)
import XCTest
@testable import Lumi

@MainActor
final class EditorAppearanceControllerTests: XCTestCase {
    func testSyncThemeSilentlyReturnsTrueWhenThemesDiffer() {
        let controller = EditorAppearanceController()
        XCTAssertTrue(controller.syncThemeSilently(currentThemeId: "a", incomingThemeId: "b"))
    }

    func testSyncThemeSilentlyReturnsFalseWhenThemesMatch() {
        let controller = EditorAppearanceController()
        XCTAssertFalse(controller.syncThemeSilently(currentThemeId: "a", incomingThemeId: "a"))
    }
}
#endif
