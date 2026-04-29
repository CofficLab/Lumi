#if canImport(XCTest)
import XCTest
@testable import Lumi

@MainActor
final class EditorConfigControllerTests: XCTestCase {
    func testPersistConfigRoundTripsSnapshotValues() {
        let controller = EditorConfigController()
        let snapshot = EditorConfigSnapshot(
            fontSize: 15,
            tabWidth: 2,
            useSpaces: false,
            formatOnSave: true,
            organizeImportsOnSave: true,
            fixAllOnSave: false,
            trimTrailingWhitespaceOnSave: false,
            insertFinalNewlineOnSave: true,
            wrapLines: false,
            showMinimap: false,
            showGutter: true,
            showFoldingRibbon: false,
            currentThemeId: "xcode-light",
            sidePanelWidth: 420
        )

        controller.persistConfig(snapshot)
        let restored = controller.restoreConfig(clampedSidePanelWidth: { CGFloat($0) })

        XCTAssertEqual(restored.fontSize, 15)
        XCTAssertEqual(restored.tabWidth, 2)
        XCTAssertEqual(restored.useSpaces, false)
        XCTAssertEqual(restored.formatOnSave, true)
        XCTAssertEqual(restored.organizeImportsOnSave, true)
        XCTAssertEqual(restored.currentThemeId, "xcode-light")
        XCTAssertEqual(restored.sidePanelWidth, 420)
    }
}
#endif
