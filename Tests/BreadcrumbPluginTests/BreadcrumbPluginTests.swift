#if canImport(XCTest)
import SwiftUI
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

    func testPluginProvidesToolbarViewForEditorIcon() async {
        let view = await BreadcrumbPlugin.shared.addToolBarCenterView(activeIcon: EditorPlugin.iconName)
        XCTAssertNotNil(view)
    }

    func testPluginProvidesRootOverlayAndAgentTools() async {
        let rootView = await BreadcrumbPlugin.shared.addRootView {
            EmptyView()
        }
        let tools = await BreadcrumbPlugin.shared.agentTools()
        let middlewares = await BreadcrumbPlugin.shared.sendMiddlewares()

        XCTAssertNotNil(rootView)
        XCTAssertEqual(tools.count, 5)
        XCTAssertTrue(middlewares.isEmpty)
    }
}
#endif
