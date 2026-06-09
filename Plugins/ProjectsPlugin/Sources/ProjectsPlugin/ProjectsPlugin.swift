import LumiCoreKit

public enum ProjectsPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.projects",
        displayName: "Projects",
        description: "Adds a project manager control to the title toolbar."
    )

    @MainActor
    public static func titleToolbarItems(context: LumiPluginContext) -> [LumiTitleToolbarItem] {
        let projectPathStore = context.resolve(LumiCurrentProjectPathStoring.self)
        return [
            LumiTitleToolbarItem(
                id: "\(info.id).toolbar",
                title: "Projects",
                placement: .center
            ) {
                ProjectControlView(projectPathStore: projectPathStore)
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
