import KitAgentTool
import KernelCore
import ProviderChatSection
import ProviderAgentRules
import ProviderLifecycleHooks
import ProviderProject
import ProviderSettingView
import ProviderToolManager
import SwiftUI
import KitSuperLog
import os

/// Agent Rules 插件（KernelCore 版本）
///
/// 由旧版 `Plugins/AgentRulesPlugin`（KernelLumi / LumiPlugin 架构）复刻而来：
/// - `onBoot` 解析内核 `ProjectProviding`（供工具与设置视图使用），
///   向 `ToolManagerProviding` 注册 2 个工具（list / create rule），
///   并向 `SettingViewProviding` 注册设置页；
/// - `onShutdown` 撤回全部贡献。
///
/// 与旧版的对应关系：
/// - `agentTools` → `ToolManagerProviding`；
/// - `settingsTabItems` → `SettingViewProviding.addEntries`（`SettingEntryItem`）；
/// - `kernel.currentProjectPath` / `kernel.project` → `AgentRulesRuntime` 持有的 `ProjectProviding`。
@MainActor
public final class AgentRulesPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.agent-rules", category: "AgentRules")
    public let id = "com.coffic.lumi.plugin.agent-rules"
    public let order = 50
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.agent-rules",
        name: "Agent Rules",
        description: "",
        category: .general,
        stage: .stable,
        policy: .alwaysOn
    )

    public init() {}

    public var name: String {
        LumiPluginLocalization.string("Agent Rules", bundle: .module)
    }

    private var projectObserver: AgentRulesProjectObserver?
    private let settingsViewModel = AgentRulesViewModel()
    private var toolbarProjectObserver: AgentRulesToolbarProjectObserver?
    private var toolbarViewModel: AgentRulesToolbarViewModel?
    private var ruleInjectionHook: AgentRuleInjectionHook?
    private var lifecycleHandles: [any LifecycleHookHandle] = []

    public func onBoot(kernel: KernelCoreContainer) throws {
        projectObserver?.cancel()
        projectObserver = nil
        toolbarProjectObserver?.cancel()
        toolbarViewModel?.cancel()
        toolbarProjectObserver = nil
        toolbarViewModel = nil
        for handle in lifecycleHandles { handle.cancel() }
        lifecycleHandles.removeAll()
        ruleInjectionHook = nil

        // 配置运行时：项目服务（工具 fallback 到当前项目路径）。
        let project = kernel.resolveProvider((any ProjectProviding).self)
        AgentRulesRuntime.configure(project: project)
        let projectObserver = AgentRulesProjectObserver(
            projectProvider: project,
            viewModel: settingsViewModel
        )
        self.projectObserver = projectObserver

        // 在 LLM 请求前注入项目规则和已启用插件贡献的规则。
        if let hooks = kernel.resolveProvider((any LifecycleHooksProviding).self) {
            let hook = AgentRuleInjectionHook(
                project: project,
                ruleProvider: kernel.resolveProvider((any AgentRuleProviding).self)
            )
            ruleInjectionHook = hook
            let handle = hooks.addWillSendToLLMHook { [weak hook] context in
                guard let hook else { return context }
                return await hook.apply(to: context)
            }
            lifecycleHandles.append(handle)
        }

        // 注册 Agent 工具。
        if let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) {
            for tool in Self.agentTools {
                toolManager.add(tool, pluginID: id)
            }
        }

        // 设置页（沿用旧版 settingsTabItems）。
        if let settings = kernel.resolveProvider((any SettingViewProviding).self) {
            settings.addEntries([
                SettingEntryItem(
                    id: "\(id).settings",
                    title: name,
                    systemImage: "doc.text",
                    order: order
                ) {
                    AgentRulesSettingsView(viewModel: self.settingsViewModel)
                },
            ])
        }

        // 3. Chat 工具栏规则入口。
        if let chat = kernel.resolveProvider((any ChatSectionProviding).self) {
            let toolbarViewModel = AgentRulesToolbarViewModel()
            let toolbarProjectObserver = AgentRulesToolbarProjectObserver(
                projectProvider: project,
                viewModel: toolbarViewModel
            )
            self.toolbarViewModel = toolbarViewModel
            self.toolbarProjectObserver = toolbarProjectObserver

            chat.addBarItems([
                ChatSectionBarItem(
                    id: "\(id).toolbar",
                    order: 50,
                    placement: .toolbarTrailing
                ) {
                    AgentRulesChatToolbarView(viewModel: toolbarViewModel)
                },
            ])
        }
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        if let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) {
            for tool in Self.agentTools {
                toolManager.remove(id: tool.name)
            }
        }
        kernel.resolveProvider((any SettingViewProviding).self)?
            .removeEntries(ids: ["\(id).settings"])
        kernel.resolveProvider((any ChatSectionProviding).self)?
            .removeBarItem(id: "\(id).toolbar")
        toolbarProjectObserver?.cancel()
        toolbarProjectObserver = nil
        toolbarViewModel?.cancel()
        toolbarViewModel = nil
        projectObserver?.cancel()
        projectObserver = nil
        AgentRulesRuntime.reset()
        for handle in lifecycleHandles { handle.cancel() }
        lifecycleHandles.removeAll()
        ruleInjectionHook = nil
    }

    // MARK: - Agent Tools

    public static let agentTools: [any SuperAgentTool] = [
        ListAgentRulesTool(),
        CreateAgentRuleTool(),
    ]
}
