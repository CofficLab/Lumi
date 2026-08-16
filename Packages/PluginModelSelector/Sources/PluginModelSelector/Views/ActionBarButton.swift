import LumiUI
import ProviderLLMManager
import SwiftUI

/// Action Bar 上的模型选择按钮（由旧版 ModelSelectorPlugin 复刻）。
///
/// 通过 `ObservableLLMProviderManagerBox` 订阅 `LLMProviderManagerProviding`
/// 的选中/注册变化（替代旧版的 `.onLumiSelectedRemoteProviderIDDidChange`
/// 等通知订阅），按钮标签实时反映「供应商 · 模型」。
struct ActionBarButton: View {
    @LumiTheme private var theme
    @ObservedObject var box: ObservableLLMProviderManagerBox

    @State private var isPopoverPresented = false

    private var manager: (any LLMProviderManagerProviding)? { box.manager }

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
                isPresented: $isPopoverPresented
            )
        }
        .accessibilityLabel("Select Model")
    }

    private var buttonLabel: String {
        guard let manager else { return "Select Provider" }
        guard let providerID = manager.selectedProviderID,
              let provider = manager.provider(id: providerID)
        else {
            return "Select Provider"
        }
        let info = provider.providerInfo
        if let model = manager.selectedModel {
            let displayModel = info.models.first(where: { $0.id == model })?.displayName ?? model
            return "\(info.displayName) · \(displayModel)"
        }
        return info.displayName
    }
}
