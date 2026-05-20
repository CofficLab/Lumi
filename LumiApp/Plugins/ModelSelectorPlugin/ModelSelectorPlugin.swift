import SwiftUI
import os

/// 模型选择器插件
///
/// 在右侧栏底部工具栏注入模型选择器按钮。
/// 点击后弹出 Popover 展示 ModelSelectorView。
/// 通过 `AppLLMVM` 读写当前供应商和模型状态。
actor ModelSelectorPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.model-selector")

    nonisolated static let emoji = "🌐"
    nonisolated static let verbose: Bool = false
    static let id = "ModelSelector"
    static let displayName = String(localized: "Model Selector", table: "AgentChat")
    static let description = String(localized: "Select LLM provider and model", table: "AgentChat")
    static let iconName = "globe"
    static var order: Int { 84 }
    nonisolated static let enable: Bool = true
    static let shared = ModelSelectorPlugin()

    // MARK: - Lifecycle

    nonisolated func onRegister() {}
    nonisolated func onEnable() {}
    nonisolated func onDisable() {}

    // MARK: - Agent Tools

    @MainActor
    func agentTools(context: ToolContext) -> [SuperAgentTool] {
        guard let llmVM = context.llmVM else { return [] }
        return [SwitchModelTool(llmVM: llmVM)]
    }

    // MARK: - Root View

    @MainActor
    func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        AnyView(AvailabilityOverlay(content: content()))
    }

    // MARK: - Sidebar Toolbar

    @MainActor func addSidebarLeadingToolbarItems(activeIcon: String?) -> [SidebarToolbarItem] {
        guard activeIcon == EditorPlugin.iconName else { return [] }
        return [
            SidebarToolbarItem(
                id: "model-selector",
                title: String(localized: "Select Model", table: "AgentChat"),
                systemImage: "globe",
                priority: 20
            )
        ]
    }

    @MainActor func addSidebarToolbarItemView(itemId: String, activeIcon: String?) -> AnyView? {
        switch itemId {
        case "model-selector":
            return AnyView(ModelSelectorToolbarButton())
        default:
            return nil
        }
    }
}
