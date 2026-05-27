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

    func testToolbarCenterViewIsHiddenForNonProjectIcon() async {
        let context = PluginContext(activeIcon: "not-editor", showsProjectToolbar: false)
        let view = await RecentProjectsPlugin.shared.addToolBarCenterView(context: context)
        XCTAssertNil(view)
    }

    func testPluginProvidesToolbarViewForProjectIcon() async {
        // EditorPlugin 的 ViewContainerItem 声明了 showsProjectToolbar: true，
        // 因此当其 showsProjectToolbar 为 true 时，工具栏中间应显示项目管理视图。
        let context = PluginContext(activeIcon: EditorPlugin.iconName, showsProjectToolbar: true)
        let view = await RecentProjectsPlugin.shared.addToolBarCenterView(context: context)
        XCTAssertNotNil(view)
    }

    func testPluginProvidesRootOverlayAndAgentTools() async {
        let rootView = await RecentProjectsPlugin.shared.addRootView {
            EmptyView()
        }
        let context = ToolContext(toolService: ToolService(), llmService: nil, llmVM: nil, conversationVM: nil)
        let tools = await RecentProjectsPlugin.shared.agentTools(context: context)

        XCTAssertNotNil(rootView)
        XCTAssertEqual(tools.count, 3)
    }
}
#endif
