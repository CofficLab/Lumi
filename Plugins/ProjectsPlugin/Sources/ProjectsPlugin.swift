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

    /// 插件数据存储的子目录名称
    public static let dataDirectoryName = "Projects"

    // MARK: - Lifecycle Managed Instances

    @MainActor
    public static var store: ProjectsStore?
    
    @MainActor
    public static var syncCoordinator: ProjectsSyncCoordinator?
    
    @MainActor
    public static var viewModel: ProjectsViewModel?

    @MainActor
    public static func lifecycle(_ event: LumiPluginLifecycle) {
        switch event {
        case .didRegister:
            let directory = LumiCore.current?.pluginDataDirectory(for: dataDirectoryName)
                ?? FileManager.default.temporaryDirectory.appendingPathComponent("Lumi/\(dataDirectoryName)")
            
            // 初始化 Store
            let storeInstance = ProjectsStore(pluginDirectory: directory)
            Self.store = storeInstance
            
            // 初始化 ViewModel
            let viewModelInstance = ProjectsViewModel(store: storeInstance)
            Self.viewModel = viewModelInstance
            
            // 初始化 SyncCoordinator 并注入 LumiCore
            let coordinator = ProjectsSyncCoordinator(viewModel: viewModelInstance)
            coordinator.lumiCore = LumiCore.current
            Self.syncCoordinator = coordinator
            
        case .willDisable:
            Self.store = nil
            Self.syncCoordinator = nil
            Self.viewModel = nil
        default:
            break
        }
    }

    @MainActor
    public static func titleToolbarItems(context: LumiPluginContext) -> [LumiTitleToolbarItem] {
        guard let viewModel else { return [] }
        return [
            LumiTitleToolbarItem(
                id: "\(info.id).toolbar",
                title: "Projects",
                placement: .center
            ) {
                ProjectControlView(viewModel: viewModel)
            }
        ]
    }

    @MainActor
    public static func sendMiddlewares(context: LumiPluginContext) -> [any LumiSendMiddleware] {
        [ConversationHintMiddleware()]
    }

    @MainActor
    public static func agentTools(context: LumiPluginContext) -> [any LumiAgentTool] {
        // Tools access store dynamically via ProjectsPlugin.store inside MainActor.run
        guard Self.viewModel != nil else { return [] }
        return [
            AddProjectTool(),
            ListProjectsTool(),
            GetCurrentProjectTool()
        ]
    }
}
