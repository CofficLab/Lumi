import SwiftUI

/// 模型选择器工具栏按钮
///
/// 显示当前供应商 + 模型名称，点击弹出 ModelSelectorView 的 Popover。
struct ModelSelectorToolbarButton: View {
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
            if llmVM.isAutoMode {
                return "Auto"
            }
            return String(localized: "No Model Selected", table: "AgentChat")
        }

        let displayModel: String
        if let localProvider = llmVM.createProvider(id: llmVM.selectedProviderId) as? any SuperLocalLLMProvider,
           let name = localProvider.displayName(forModelId: model) {
            displayModel = name
        } else {
            displayModel = model
        }

        if llmVM.isAutoMode {
            return "Auto · \(displayModel)"
        }

        guard let providerType = llmVM.providerType(forId: llmVM.selectedProviderId) else {
            return displayModel
        }
        return "\(providerType.displayName) · \(displayModel)"
    }
}
