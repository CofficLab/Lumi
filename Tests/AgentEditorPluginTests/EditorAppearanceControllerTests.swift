#if canImport(XCTest)
import XCTest
@testable import Lumi

@MainActor
final class EditorAppearanceControllerTests: XCTestCase {
    func testClampedSidePanelWidthRespectsBounds() {
        let controller = EditorAppearanceController()

        XCTAssertEqual(controller.clampedSidePanelWidth(100), 240)
        XCTAssertEqual(controller.clampedSidePanelWidth(500), 500)
        XCTAssertEqual(controller.clampedSidePanelWidth(1000), 720)
    }

    func testUpdateSidePanelWidthUsesClamp() {
        let controller = EditorAppearanceController()
        XCTAssertEqual(controller.updateSidePanelWidth(currentWidth: 300, delta: -100), 240)
    }
}
#endif
