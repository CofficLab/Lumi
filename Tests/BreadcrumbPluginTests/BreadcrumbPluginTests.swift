#if canImport(XCTest)
import XCTest
@testable import Lumi

@MainActor
final class BreadcrumbPluginTests: XCTestCase {

    func testPluginMetadataRemainsStable() {
        XCTAssertEqual(BreadcrumbPlugin.id, "Breadcrumb")
        XCTAssertEqual(BreadcrumbPlugin.iconName, "folder")
        XCTAssertTrue(BreadcrumbPlugin.enable)
        XCTAssertEqual(BreadcrumbPlugin.order, 10)
        XCTAssertFalse(BreadcrumbPlugin.isConfigurable)
    }

    func testToolbarCenterViewIsHiddenForNonEditorIcon() async {
        let view = await BreadcrumbPlugin.shared.addToolBarCenterView(activeIcon: "not-editor")
        XCTAssertNil(view)
    }
}
#endif
