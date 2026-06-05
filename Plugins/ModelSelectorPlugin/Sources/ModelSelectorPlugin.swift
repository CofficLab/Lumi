import LumiCoreKit
import SuperLogKit
import SwiftUI
import AgentToolKit
import os

/// 模型选择器插件
///
/// 在右侧栏底部工具栏注入模型选择器按钮。
/// 点击后弹出 Popover 展示 ModelSelectorView。
/// 通过 `AppLLMVM` 读写当前供应商和模型状态。
public actor ModelSelectorPlugin: SuperPlugin, SuperLog {
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.model-selector")

    public nonisolated static let emoji = "🌐"
    public nonisolated static let verbose: Bool = true
    public static let id = "ModelSelector"
    public static let displayName = String(localized: "Model Selector", bundle: .module)
    public static let description = String(localized: "Select LLM provider and model", bundle: .module)
    public static let iconName = "globe"
    public static var category: PluginCategory { .agent }
    public static var order: Int { 84 }
    public nonisolated static let policy: PluginPolicy = .alwaysOn
    public static let shared = ModelSelectorPlugin()

    // MARK: - Lifecycle

    public nonisolated func onRegister() {}
    public nonisolated func onEnable() {}
    public nonisolated func onDisable() {}

    // MARK: - Agent Tools

    @MainActor
    public func agentTools(context: ToolContext) -> [SuperAgentTool] {
        // TODO: 暂时注释掉，后续恢复
//        guard let llmVM = context.llmVM,
//              let conversationVM = context.conversationVM else { return [] }
//        return [SwitchModelTool(llmVM: llmVM, conversationVM: conversationVM)]
        return []
    }

    // MARK: - Root View

    @MainActor
    public func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        AnyView(AvailabilityOverlay(content: content()))
    }

    // MARK: - Sidebar Toolbar

    @MainActor public func addSidebarLeadingToolbarItems(context: PluginContext) -> [SidebarToolbarItem] {
        guard context.showChat else { return [] }
        return [
            SidebarToolbarItem(
                id: "model-selector",
                title: String(localized: "Select Model", bundle: .module),
                systemImage: "globe",
                priority: 20
            )
        ]
    }

    @MainActor public func addSidebarToolbarItemView(itemId: String, context: PluginContext) -> AnyView? {
        switch itemId {
        case "model-selector":
            return AnyView(ModelSelectorToolbarButton())
        default:
            return nil
        }
    }
}
