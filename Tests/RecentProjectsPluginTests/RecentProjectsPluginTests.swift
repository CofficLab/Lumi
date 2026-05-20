#if canImport(XCTest)
import SwiftUI
import XCTest
@testable import Lumi

@MainActor
final class RecentProjectsPluginTests: XCTestCase {

    func testPluginMetadataRemainsStable() {
        XCTAssertEqual(RecentProjectsPlugin.id, "RecentProjects")
        XCTAssertEqual(RecentProjectsPlugin.iconName, "folder")
        XCTAssertTrue(RecentProjectsPlugin.enable)
        XCTAssertEqual(RecentProjectsPlugin.order, 10)
        XCTAssertFalse(RecentProjectsPlugin.isConfigurable)
    }

    func testToolbarCenterViewIsHiddenForNonEditorIcon() async {
        let view = await RecentProjectsPlugin.shared.addToolBarCenterView(activeIcon: "not-editor")
        XCTAssertNil(view)
    }

    func testPluginProvidesToolbarViewForEditorIcon() async {
        let view = await RecentProjectsPlugin.shared.addToolBarCenterView(activeIcon: EditorPlugin.iconName)
        XCTAssertNotNil(view)
    }

    func testPluginProvidesRootOverlayAndAgentTools() async {
        let rootView = await RecentProjectsPlugin.shared.addRootView {
            EmptyView()
        }
        let context = ToolContext(toolService: ToolService(), llmService: nil)
        let tools = await RecentProjectsPlugin.shared.agentTools(context: context)

        XCTAssertNotNil(rootView)
        XCTAssertEqual(tools.count, 3)
    }
}
#endif
