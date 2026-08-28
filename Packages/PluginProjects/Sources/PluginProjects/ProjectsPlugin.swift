import KitAgentTool
import Foundation
import KitLLM
import KernelCore
import os
import ProviderProject
import ProviderProjectRAG
import ProviderLifecycleHooks
import ProviderSettingView
import ProviderStorage
import ProviderToolbar
import ProviderToolManager
import ProviderPromptSuggestion
import KitSuperLog
import SwiftUI

/// 项目管理插件。
///
/// - `onBoot` 中装配带持久化的 `ProjectsStore` + `ProjectsViewModel`，
///   并通过 `ProjectProvidingObserver` 将内核 `ProjectProviding` 的状态同步到插件;
/// - 注册 Agent 工具（list_projects / add_project / get_current_project）;
/// - 贡献标题栏项目控件与设置页;
/// - 通过 `willSendToLLM` 钩子将当前项目路径注入 LLM 上下文;
///   「添加项目」动作胶囊。
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

    private var viewModel: ProjectsViewModel?
    private var projectObserver: ProjectProvidingObserver?

    public init() {}

    private var promptSuggestion: PromptSuggestion {
        PromptSuggestion(id: "\(id).add", title: LumiPluginLocalization.string("Add Project", bundle: .module), order: order * 1_000, systemImage: "folder.badge.plus", action: .pickProjectFolder, visibility: .onlyWithoutProject, style: .additive)
    }
    private func registerPromptSuggestion(kernel: KernelCoreContainer, requiresEnable: Bool) {
        var suggestion = promptSuggestion
        suggestion.pluginID = id
        suggestion.requiresEnable = requiresEnable
        kernel.resolveProvider((any PromptSuggestionProviding).self)?.register(suggestion)
    }
    public func onRegister(kernel: KernelCoreContainer) throws { registerPromptSuggestion(kernel: kernel, requiresEnable: !kernel.isPluginEnabled(id: id)) }

    /// 存储目录 key，用于 `storage.pluginDataDirectory(for:)`。
    static let storageDirectoryKey = "Projects"

    public func onBoot(kernel: KernelCoreContainer) throws {
        // 1. 装配存储（应用数据目录按 storage key "Projects" 隔离）
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

        guard let projectProvider = kernel.resolveProvider((any ProjectProviding).self) else {
            Self.logger.error("\(Self.t)Failed to resolve ProjectProviding")
            return
        }

        // 3. 恢复到 ProjectProviding。恢复只发生在启动装配阶段；运行时的
        // 项目列表和当前项目始终以 ProjectProviding 为唯一来源。
        let storedProjects = store.loadProjects()
        if projectProvider.projects.isEmpty {
            projectProvider.synchronizeProjects(storedProjects.map {
                ProjectInfo(name: $0.name, path: $0.path, language: $0.language)
            })
        }
        let storedCurrentProject = store.loadCurrentProject(from: storedProjects)

        // 4. 初始化 ViewModel，并注册 Provider → ViewModel observer。
        let viewModel = ProjectsViewModel(store: store, projectProvider: projectProvider)
        self.viewModel = viewModel
        projectObserver?.cancel()
        let projectObserver = ProjectProvidingObserver(project: projectProvider, viewModel: viewModel)
        self.projectObserver = projectObserver
        ProjectsRuntime.configure(viewModel: viewModel, projectObserver: projectObserver)

        // 恢复当前项目必须通过 ProjectProviding 执行，observer 会负责同步 ViewModel。
        if projectProvider.currentProject == nil, let storedCurrentProject {
            Task { @MainActor in
                do {
                    try await projectProvider.openProject(at: storedCurrentProject.path)
                } catch {
                    Self.logger.error("\(Self.t)Failed to restore current project: \(error.localizedDescription)")
                }
            }
        }

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
                    title: LumiPluginLocalization.string("Projects", bundle: .module),
                    placement: .center,
                    order: 0
                ) {
                    ControlView(viewModel: viewModel)
                },
            ])
        }

        // 7. 贡献设置入口
        if let settings = kernel.resolveProvider((any SettingViewProviding).self) {
            settings.addProjectDetailSections([
                ProjectDetailSectionItem(
                    id: "\(id).rag-status",
                    order: 150
                ) { projectPath in
                    ProjectRAGStatusSection(projectPath: projectPath) {
                        kernel.resolveProvider((any ProjectRAGProviding).self)
                    }
                }
            ])
            settings.addEntries([
                SettingEntryItem(
                    id: "\(id).settings",
                    title: LumiPluginLocalization.string("Projects", bundle: .module),
                    systemImage: "folder",
                    order: order
                ) {
                    SettingsView(viewModel: viewModel, projectDetailSections: settings.projectDetailSections)
                },
            ])
        }
    }

    public func onReady(kernel: KernelCoreContainer) throws {
        registerPromptSuggestion(kernel: kernel, requiresEnable: false)
    }

    public func onEnable(kernel: KernelCoreContainer) async throws {
        registerPromptSuggestion(kernel: kernel, requiresEnable: false)
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        projectObserver?.cancel()
        projectObserver = nil
        viewModel = nil
        if let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) {
            for tool in Self.agentTools {
                toolManager.remove(id: tool.name)
            }
        }
        kernel.resolveProvider((any ToolbarProviding).self)?
            .removeToolbarItems(ids: ["\(id).toolbar"])
        kernel.resolveProvider((any SettingViewProviding).self)?
            .removeEntries(ids: ["\(id).settings"])
        kernel.resolveProvider((any SettingViewProviding).self)?
            .removeProjectDetailSections(ids: ["\(id).rag-status"])
        ProjectsRuntime.reset()
    }

    public func onDisable(kernel: KernelCoreContainer) async throws {
        registerPromptSuggestion(kernel: kernel, requiresEnable: true)
    }
    public func onUnregister(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any PromptSuggestionProviding).self)?.unregister(id: promptSuggestion.id)
    }

    // MARK: - Agent Tools

    /// 本插件贡献的 Agent 工具。
    public static let agentTools: [any SuperAgentTool] = [
        ListProjectsTool(),
        AddProjectTool(),
        GetCurrentProjectTool(),
    ]
}
