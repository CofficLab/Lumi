import LumiKernel
import LumiKernel
import LumiUI
import SwiftUI

struct ChatMessagesSectionView: View {
    @ObservedObject var coordinator: ChatSectionCoordinator

    var body: some View {
        let selectedID = coordinator.selectedConversationID
        let messages = selectedID.map { coordinator.displayedMessages(for: $0) } ?? []
        let isSending = coordinator.chatService.isSending(for: selectedID)

        VStack(spacing: 0) {
            ChatMessageListView(
                messages: messages,
                isSending: isSending,
                hasEarlierMessages: selectedID.map {
                    coordinator.chatService.hasEarlierMessages(for: $0, beforeMessageID: coordinator.oldestVisibleMessageID)
                } ?? false,
                rendererForMessage: { coordinator.chatService.renderer(for: $0) },
                rawMessageBinding: coordinator.rawMessageBinding(for:),
                onUseAsDraft: { message in
                    coordinator.draft = message.content
                },
                onResend: { message in
                    guard let selectedID else { return }
                    Task {
                        await coordinator.chatService.resendMessage(id: message.id, in: selectedID)
                    }
                },
                onDelete: { message in
                    guard let selectedID else { return }
                    coordinator.chatService.deleteMessage(id: message.id, in: selectedID)
                },
                onLoadEarlier: coordinator.loadEarlierMessages,
                onQuickStart: { prompt in
                    coordinator.draft = prompt
                    coordinator.send()
                },
                automationLevel: coordinator.chatService.automationLevel(for: selectedID),
                verbosity: coordinator.chatService.verbosity(for: selectedID)
            )
            .environment(\.lumiResponseVerbosity, coordinator.chatService.verbosity(for: selectedID))
            .id(selectedID)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onChange(of: coordinator.chatService.selectedConversationID) { _, _ in
            coordinator.resetOldestVisibleMessageID()
        }
        .onReceive(NotificationCenter.default.publisher(for: .lumiResendMessage)) { notification in
            guard let messageID = notification.userInfo?[LumiMessageSavedNotification.messageIDKey] as? UUID,
                  let conversationID = notification.userInfo?[LumiMessageSavedNotification.conversationIDKey] as? UUID
            else {
                return
            }
            Task {
                await coordinator.chatService.resendMessage(id: messageID, in: conversationID)
            }
        }
    }
}
