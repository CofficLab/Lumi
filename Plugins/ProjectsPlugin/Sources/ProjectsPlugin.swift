import LumiCoreKit
import SwiftUI

public enum ProjectsPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.projects",
        displayName: LumiPluginLocalization.string("Projects", bundle: .module),
        description: LumiPluginLocalization.string("Adds a project manager control to the title toolbar.", bundle: .module)
    )

    /// 全局共享的 Store 实例，供插件内所有组件统一访问
    public static let sharedStore = ProjectsStore.shared

    @MainActor
    public static func titleToolbarItems(context: LumiPluginContext) -> [LumiTitleToolbarItem] {
        return [
            LumiTitleToolbarItem(
                id: "\(info.id).toolbar",
                title: "Projects",
                placement: .center
            ) {
                ProjectControlView(store: sharedStore)
            }
        ]
    }

    @MainActor
    public static func sendMiddlewares(context: LumiPluginContext) -> [any LumiSendMiddleware] {
        [ConversationHintMiddleware()]
    }

    @MainActor
    public static func agentTools(context: LumiPluginContext) -> [any LumiAgentTool] {
        [
            AddProjectTool(),
            ListProjectsTool(),
            GetCurrentProjectTool()
        ]
    }
}
