import LumiCoreChat
import LumiKernel
import LumiUI
import SwiftUI

/// Action Bar 上的模型选择按钮
struct ModelSelectorActionBarButton: View {
    @LumiTheme private var theme
    @ObservedObject private var chatService: ChatService

    init(chatService: any LumiChatServicing) {
        guard let chatService = chatService as? ChatService else {
            preconditionFailure("ModelSelectorActionBarButton requires ChatService")
        }
        _chatService = ObservedObject(wrappedValue: chatService)
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "globe")
                .font(.system(size: 13, weight: .medium))
            Text(providerLabel)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .foregroundColor(theme.textSecondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(theme.textTertiary.opacity(0.2))
        )
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
            return "Select Model"
        }

        if let model = chatService.modelName(for: conversationID) {
            let displayModel = provider.modelDisplayNames[model] ?? model
            return "\(provider.displayName) · \(displayModel)"
        }
        return provider.displayName
    }
}
