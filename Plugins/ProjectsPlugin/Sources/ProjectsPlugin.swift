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

    public static func titleToolbarItems(context: LumiPluginContext) -> [LumiTitleToolbarItem] {
        return [
            LumiTitleToolbarItem(
                id: "\(info.id).toolbar",
                title: "Projects",
                placement: .center
            ) {
                ProjectControlView(store: ProjectsStore.shared)
            }
        ]
    }

    public static func sendMiddlewares(context: LumiPluginContext) -> [any LumiSendMiddleware] {
        [ConversationHintMiddleware()]
    }

    public static func agentTools(context: LumiPluginContext) -> [any LumiAgentTool] {
        [
            AddProjectTool(),
            ListProjectsTool(),
            GetCurrentProjectTool()
        ]
    }
}
