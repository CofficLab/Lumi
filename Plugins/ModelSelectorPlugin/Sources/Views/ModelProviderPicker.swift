import LLMProviderManagerPlugin
import LumiKernel
import LumiUI
import SwiftUI

struct ModelProviderPicker: View {
    @LumiTheme private var theme
    let chatService: any LumiChatServicing
    /// 由 `LLMProviderManager` 暴露的共享 provider 可用性状态。
    /// 为 nil 时,内部 `ModelSelectorView` 会创建自己的本地实例。
    let availability: ModelAvailabilityState?

    @State private var isPresented = false
    @State private var isHovering = false

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            HStack(spacing: ToolbarMetrics.composerChipSpacing) {
                Image(systemName: "globe")
                    .font(.system(size: ToolbarMetrics.composerChipIconSize, weight: .medium))
                Text(providerLabel)
                    .font(.system(size: ToolbarMetrics.composerChipTextSize, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Image(systemName: "chevron.up")
                    .font(.system(size: ToolbarMetrics.chevronSize, weight: ToolbarMetrics.chevronWeight))
                    .foregroundColor(theme.textSecondary)
            }
            .foregroundColor(theme.textSecondary)
            .padding(.horizontal, ToolbarMetrics.composerChipHorizontalPadding)
            .padding(.vertical, ToolbarMetrics.composerChipVerticalPadding)
            .background(
                RoundedRectangle(cornerRadius: ToolbarMetrics.chipCornerRadius, style: .continuous)
                    .fill(isHovering ? theme.textPrimary.opacity(0.08) : Color.clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: ToolbarMetrics.chipCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            ModelSelectorView(
                chatService: chatService,
                externalAvailability: availability,
                onClose: {
                    isPresented = false
                }
            )
        }
        .frame(maxWidth: 320, alignment: .leading)
        .accessibilityLabel(LumiPluginLocalization.string("Select Model"))
    }

    private var providerLabel: String {
        if chatService.routingMode == .auto {
            return LumiPluginLocalization.string("Auto · Router")
        }

        let conversationID = chatService.selectedConversationID
        guard let providerID = chatService.providerID(for: conversationID),
              let provider = chatService.providerInfos.first(where: { $0.id == providerID })
        else {
            return LumiPluginLocalization.string("Local Placeholder")
        }

        if let model = chatService.modelName(for: conversationID) {
            let displayModel = provider.modelDisplayNames[model] ?? model
            return "\(provider.displayName) · \(displayModel)"
        }
        return provider.displayName
    }
}
