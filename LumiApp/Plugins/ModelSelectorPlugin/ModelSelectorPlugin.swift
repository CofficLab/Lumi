import MagicKit
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

    // MARK: - Sidebar Toolbar

    @MainActor func addSidebarToolbarItems(activeIcon: String?) -> [SidebarToolbarItem] {
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
        guard itemId == "model-selector" else { return nil }
        return AnyView(ModelSelectorToolbarButton())
    }
}

// MARK: - Toolbar Button View

/// 模型选择器工具栏按钮
///
/// 显示当前供应商 + 模型名称，点击弹出 ModelSelectorView 的 Popover。
private struct ModelSelectorToolbarButton: View {
    @EnvironmentObject private var llmVM: AppLLMVM
    @EnvironmentObject private var themeVM: AppThemeVM

    /// Popover 显示状态
    @State private var isPresented = false

    var body: some View {
        Button(action: {
            isPresented = true
        }) {
            HStack(spacing: 4) {
                Image(systemName: "globe")
                    .font(.system(size: 13))
                Text(currentModelDisplayText)
                    .font(.system(size: 11))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Image(systemName: "chevron.up")
                    .font(.system(size: 9))
                    .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())
            }
            .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(themeVM.activeAppTheme.workspaceTextColor().opacity(0.06))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isPresented, arrowEdge: .leading) {
            ModelSelectorView()
        }
        .accessibilityLabel(String(localized: "Select Model", table: "AgentChat"))
        .accessibilityHint(String(localized: "Select Model Hint", table: "AgentChat"))
    }

    /// 当前显示的「供应商 + 模型」文案
    private var currentModelDisplayText: String {
        let model = llmVM.currentModel
        guard !model.isEmpty else {
            return String(localized: "No Model Selected", table: "AgentChat")
        }
        guard let providerType = llmVM.providerType(forId: llmVM.selectedProviderId) else {
            return model
        }
        let modelLabel: String
        if let localProvider = llmVM.createProvider(id: llmVM.selectedProviderId) as? any SuperLocalLLMProvider,
           let name = localProvider.displayName(forModelId: model) {
            modelLabel = name
        } else {
            modelLabel = model
        }
        return "\(providerType.displayName) · \(modelLabel)"
    }
}
