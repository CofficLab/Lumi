import LumiCoreKit

public enum ProjectsPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.projects",
        displayName: LumiPluginLocalization.string("Projects", bundle: .module),
        description: LumiPluginLocalization.string("Adds a project manager control to the title toolbar.", bundle: .module)
    )

    /// 插件持有的项目 Store 实例，供其他组件通过依赖注入访问
    @MainActor
    public static var sharedStore: ProjectsStore {
        guard let store = _sharedStore else {
            fatalError("ProjectsPlugin.setupStore must be called before accessing sharedStore")
        }
        return store
    }
    
    @MainActor
    private static var _sharedStore: ProjectsStore?
    
    /// 初始化插件的 Store 实例，接收内核提供的 projectStore
    /// 插件负责将内存状态持久化到磁盘，并从磁盘恢复
    @MainActor
    public static func setupStore(projectPathStore: LumiCurrentProjectPathStore, projectStore: LumiProjectStore) {
        _sharedStore = ProjectsStore(
            projectPathStore: projectPathStore,
            projectStore: projectStore
        )
    }

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
