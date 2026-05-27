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
        // EditorPlugin 的 ViewContainerItem 声明了 showsProjectToolbar: true，
        // 因此当其 activeIcon 激活时，工具栏中间应显示项目管理视图。
        let view = await RecentProjectsPlugin.shared.addToolBarCenterView(activeIcon: EditorPlugin.iconName)
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
