import AgentToolKit
import KernelCore
import ProviderProject
import ProviderSettingView
import ProviderToolManager
import SwiftUI

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
public final class AgentRulesPlugin: SuperPlugin {
    public let id = "com.coffic.lumi.plugin.agent-rules"
    public let order = 50

    public init() {}

    public var name: String {
        LumiPluginLocalization.string("Agent Rules", bundle: .module)
    }

    public var metadata: PluginMetadata {
        PluginMetadata(
            id: id,
            name: "Agent Rules",
            description: "Manage rule documents in .agent/rules directory.",
            category: .general,
            stage: .preview,
            policy: .required
        )
    }

    public func onBoot(kernel: KernelCoreContainer) throws {
        // 配置运行时：项目服务（工具 fallback 到当前项目路径）。
        let project = kernel.resolveProvider((any ProjectProviding).self)
        AgentRulesRuntime.configure(project: project)

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
                    AgentRulesSettingsView(projectProvider: project)
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
        AgentRulesRuntime.reset()
    }

    // MARK: - Agent Tools

    public static let agentTools: [any SuperAgentTool] = [
        ListAgentRulesTool(),
        CreateAgentRuleTool(),
    ]
}
