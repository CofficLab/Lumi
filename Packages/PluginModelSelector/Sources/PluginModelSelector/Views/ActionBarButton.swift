import LumiUI
import ProviderLLMManager
import ProviderToast
import SwiftUI

/// Action Bar 上的模型选择按钮（由旧版 ModelSelectorPlugin 复刻）。
///
/// 通过 `ObservableLLMProviderManagerBox` 订阅内核 `LLMManaging`
/// 的选中/注册变化（替代旧版的 `.onLumiSelectedRemoteProviderIDDidChange`
/// 等通知订阅），按钮标签实时反映「供应商 · 模型」。
struct ActionBarButton: View {
    @LumiTheme private var theme
    @ObservedObject var box: ObservableLLMProviderManagerBox
    @ObservedObject var usageStore: ProviderUsageStore
    let toast: (any ToastProviding)?

    @State private var isPopoverPresented = false

    var body: some View {
        Button {
            isPopoverPresented.toggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "globe")
                    .font(.appCallout)
                Text(buttonLabel)
                    .font(.appCaptionEmphasized)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Image(systemName: isPopoverPresented ? "chevron.up" : "chevron.down")
                    .font(.appMicroEmphasized)
                    .foregroundColor(theme.textTertiary)
            }
            .foregroundColor(theme.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous)
                    .fill(theme.appStatusMutedFill)
            )
            .contentShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isPopoverPresented, arrowEdge: .top) {
            PopoverContent(
                box: box,
                usageStore: usageStore,
                toast: toast,
                isPresented: $isPopoverPresented
            )
        }
        .accessibilityLabel("Select Model")
    }

    private var buttonLabel: String {
        guard let providerID = box.selectedProviderID,
              let info = box.providerInfo(id: providerID)
        else {
            return "Select Provider"
        }
        // 当前生效模型：显式选中项 > 供应商默认模型（与内核 `resolveSelected()` 回退一致），
        // 保证按钮始终反映「当前供应商 + 模型」。
        let model = box.selectedModel ?? info.defaultModel
        let displayModel = info.models.first(where: { $0.id == model })?.displayName ?? model
        return "\(info.displayName) · \(displayModel)"
    }
}
