import KitAgentTool
import Foundation
import KitLLM
import KernelCore
import os
import ProviderProject
import ProviderLifecycleHooks
import ProviderSettingView
import ProviderStorage
import ProviderToolbar
import ProviderToolManager
import ProviderPromptSuggestion
import KitSuperLog
import SwiftUI

/// 项目管理插件（KernelCore 版本）。
///
/// 由旧版 `Plugins/ProjectsPlugin`（KernelLumi / LumiPlugin）复刻而来：
/// - `onBoot` 中装配带持久化的 `ProjectsStore` + `ProjectsViewModel`,
///   并通过 `ProjectsSyncCoordinator` 与内核已注册的 `ProjectProviding` 双向同步;
/// - 注册 Agent 工具（list_projects / add_project / get_current_project）;
/// - 贡献标题栏项目控件与设置页;
/// - 通过 `willSendToLLM` 钩子将当前项目路径注入 LLM 上下文;
///   「添加项目」动作胶囊（新版 PromptSuggestion 不支持动作）。
@MainActor
public final class ProjectsPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.projects", category: "Projects")

    public let id = "com.coffic.lumi.plugin.projects"
    public let order = 5
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.projects",
        name: "Projects",
        description: "",
        category: .project,
        stage: .stable,
        policy: .alwaysOn
    )


    public init() {}

    private var promptSuggestion: PromptSuggestion {
        PromptSuggestion(id: "\(id).add", title: LumiPluginLocalization.string("Add Project", bundle: .module), order: order * 1_000, systemImage: "folder.badge.plus", action: .pickProjectFolder, visibility: .onlyWithoutProject, style: .additive)
    }

    /// 存储目录 key：必须与旧版 `Plugins/ProjectsPlugin` 的
    /// `storage.pluginDataDirectory(for: "Projects")` 完全一致，
    /// 保证新旧版本共享同一份 projects.json（<数据根>/Projects/）。
    static let storageDirectoryKey = "Projects"

    public func onBoot(kernel: KernelCoreContainer) throws {
        // 1. 装配存储（应用数据目录按旧版 storage key "Projects" 隔离）
        guard let storage = kernel.resolveProvider((any StorageProviding).self) else {
            Self.logger.error("\(Self.t)Failed to resolve StorageProviding from kernel")
            return
        }
        let store = ProjectsStore(pluginDirectory: storage.pluginDataDirectory(for: Self.storageDirectoryKey))

        // 2. v4 历史项目迁移（必须在 ViewModel 初始化之前;幂等、吞错）
        ProjectsLegacyMigration(
            currentDataRootDirectory: storage.dataRootDirectory,
            store: store
        ).run()

        // 3. 初始化 ViewModel
        let viewModel = ProjectsViewModel(store: store)

        // 4. 初始化同步协调器并绑定内核（ViewModel ↔ ProjectProviding）
        let coordinator = ProjectsSyncCoordinator(viewModel: viewModel)
        coordinator.kernel = kernel
        ProjectsRuntime.configure(viewModel: viewModel, syncCoordinator: coordinator)

        // 5. 注册 Agent 工具
        if let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) {
            for tool in Self.agentTools {
                toolManager.add(tool, pluginID: id)
            }
        }

        // 6. willSendToLLM 钩子：将当前项目路径注入 LLM 上下文。
        if let hooks = kernel.resolveProvider((any LifecycleHooksProviding).self),
           let project = kernel.resolveProvider((any ProjectProviding).self) {
            hooks.addWillSendToLLMHook { context in
                guard let projectPath = project.currentProject?.path,
                      !projectPath.isEmpty else {
                    Self.logger.error("\(Self.t)无法将当前项目路径注入 LLM 上下文：未选择项目或项目路径为空")
                    return context
                }
                var ctx = context
                let projectMessage = LLMMessage(
                    role: .system,
                    content: "当前工作项目路径：\(projectPath)"
                )
                ctx.messages = [projectMessage] + ctx.messages
                return ctx
            }
        } else {
            if kernel.resolveProvider((any LifecycleHooksProviding).self) == nil {
                Self.logger.error("\(Self.t)无法注册 willSendToLLM 钩子：LifecycleHooksProviding 未注册")
            }
            if kernel.resolveProvider((any ProjectProviding).self) == nil {
                Self.logger.error("\(Self.t)无法注册 willSendToLLM 钩子：ProjectProviding 未注册")
            }
        }

        // 7. 贡献标题栏项目控件
        if let toolbar = kernel.resolveProvider((any ToolbarProviding).self) {
            toolbar.addToolbarItems([
                ToolbarItem(
                    id: "\(id).toolbar",
                    title: "Projects",
                    placement: .center,
                    order: 0
                ) {
                    ControlView(viewModel: viewModel)
                },
            ])
        }

        // 7. 贡献设置入口
        if let settings = kernel.resolveProvider((any SettingViewProviding).self) {
            settings.addEntries([
                SettingEntryItem(
                    id: "\(id).settings",
                    title: "Projects",
                    systemImage: "folder",
                    order: order
                ) {
                    SettingsView(viewModel: viewModel)
                },
            ])
        }
    }

    public func onReady(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any PromptSuggestionProviding).self)?.register(promptSuggestion)
    }

    public func onEnable(kernel: KernelCoreContainer) async throws {
        kernel.resolveProvider((any PromptSuggestionProviding).self)?.register(promptSuggestion)
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any PromptSuggestionProviding).self)?.unregister(id: promptSuggestion.id)
        if let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) {
            for tool in Self.agentTools {
                toolManager.remove(id: tool.name)
            }
        }
        kernel.resolveProvider((any ToolbarProviding).self)?
            .removeToolbarItems(ids: ["\(id).toolbar"])
        kernel.resolveProvider((any SettingViewProviding).self)?
            .removeEntries(ids: ["\(id).settings"])
        ProjectsRuntime.reset()
    }

    public func onDisable(kernel: KernelCoreContainer) async throws {
        kernel.resolveProvider((any PromptSuggestionProviding).self)?.unregister(id: promptSuggestion.id)
    }

    // MARK: - Agent Tools

    /// 本插件贡献的 Agent 工具（复刻旧版 ProjectsPlugin.agentTools）。
    public static let agentTools: [any SuperAgentTool] = [
        ListProjectsTool(),
        AddProjectTool(),
        GetCurrentProjectTool(),
    ]
}
