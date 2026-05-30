#if canImport(XCTest)
import SwiftUI
import XCTest
import LumiCoreKit
@testable import PluginEditorPanel
@testable import PluginProjects
@testable import Lumi

@MainActor
final class RecentProjectsPluginTests: XCTestCase {

    func testPluginMetadataRemainsStable() {
        XCTAssertEqual(ProjectsPlugin.id, "Projects")
        XCTAssertEqual(ProjectsPlugin.iconName, "folder")
        XCTAssertTrue(ProjectsPlugin.enable)
        XCTAssertEqual(ProjectsPlugin.order, 10)
        XCTAssertFalse(ProjectsPlugin.isConfigurable)
    }

    func testToolbarCenterViewIsHiddenForNonProjectIcon() async {
        let context = PluginContext(activeIcon: "not-editor", showsProjectToolbar: false)
        let view = await ProjectsPlugin.shared.addToolBarCenterView(context: context)
        XCTAssertNil(view)
    }

    func testPluginProvidesToolbarViewForProjectIcon() async {
        // EditorPlugin 的 ViewContainerItem 声明了 showsProjectToolbar: true，
        // 因此当其 showsProjectToolbar 为 true 时，工具栏中间应显示项目管理视图。
        let context = PluginContext(activeIcon: EditorPlugin.iconName, showsProjectToolbar: true)
        let view = await ProjectsPlugin.shared.addToolBarCenterView(context: context)
        XCTAssertNotNil(view)
    }

    func testPluginProvidesRootOverlayAndAgentTools() async {
        let rootView = await ProjectsPlugin.shared.addRootView {
            EmptyView()
        }
        let tools = await ProjectsPlugin.shared.agentTools(context: LumiCoreKit.ToolContext())

        XCTAssertNotNil(rootView)
        XCTAssertEqual(tools.count, 3)
    }
}
#endif
