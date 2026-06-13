import LumiChatKit
import LumiCoreKit
import LumiUI
import SwiftUI

struct ModelProviderPicker: View {
    @LumiTheme private var theme
    @ObservedObject private var chatService: ChatService

    @State private var isPresented = false

    init(chatService: any LumiChatServicing) {
        guard let chatService = chatService as? ChatService else {
            preconditionFailure("ModelProviderPicker requires ChatService")
        }
        _chatService = ObservedObject(wrappedValue: chatService)
    }

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            HStack(spacing: ToolbarMetrics.chipSpacing) {
                Image(systemName: "globe")
                    .font(.system(size: ToolbarMetrics.chipIconSize, weight: .medium))
                Text(providerLabel)
                    .font(.system(size: ToolbarMetrics.chipTextSize, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Image(systemName: "chevron.up")
                    .font(.system(size: ToolbarMetrics.chevronSize, weight: ToolbarMetrics.chevronWeight))
                    .foregroundColor(theme.textSecondary)
            }
            .foregroundColor(theme.textSecondary)
            .padding(.horizontal, ToolbarMetrics.chipHorizontalPadding)
            .padding(.vertical, ToolbarMetrics.chipVerticalPadding)
            .contentShape(RoundedRectangle(cornerRadius: ToolbarMetrics.chipCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            ModelSelectorView(
                chatService: chatService,
                conversationID: chatService.selectedConversationID,
                onClose: {
                    isPresented = false
                }
            )
        }
        .frame(maxWidth: 320, alignment: .leading)
        .accessibilityLabel("Select Model")
    }

    private var providerLabel: String {
        if chatService.routingMode == .auto {
            return "Auto · Router"
        }

        let conversationID = chatService.selectedConversationID
        guard let providerID = chatService.providerID(for: conversationID),
              let provider = chatService.providerInfos.first(where: { $0.id == providerID })
        else {
            return "Local Placeholder"
        }

        if let model = chatService.modelName(for: conversationID) {
            return "\(provider.displayName) · \(model)"
        }
        return provider.displayName
    }
}
