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

    /// 插件持有的项目 Store 实例，供其他组件通过依赖注入访问
    @MainActor
    public static var sharedStore: ProjectsStore {
        guard let store = _sharedStore else {
            // 如果还没初始化，创建一个默认的
            if _sharedStore == nil {
                _sharedStore = ProjectsStore()
            }
            return _sharedStore!
        }
        return store
    }

    @MainActor
    private static var _sharedStore: ProjectsStore?

    /// 初始化插件的 Store 实例
    /// 从磁盘加载项目，并同步到 LumiCore
    @MainActor
    public static func setupStore() {
        _sharedStore = ProjectsStore()
    }

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
