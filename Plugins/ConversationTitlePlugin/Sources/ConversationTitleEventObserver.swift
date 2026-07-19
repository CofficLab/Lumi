import Foundation
import LumiKernel

@MainActor
enum ConversationTitleNotificationObserver {
    private static var observer: NSObjectProtocol?

    static func start() {
        guard observer == nil else { return }

        observer = NotificationCenter.default.addObserver(
            forName: .lumiMessageSaved,
            object: nil,
            queue: .main
        ) { notification in
            guard let userInfo = notification.userInfo,
                  let messageID = userInfo[LumiMessageSavedNotification.messageIDKey] as? UUID,
                  let conversationID = userInfo[LumiMessageSavedNotification.conversationIDKey] as? UUID,
                  let roleRaw = userInfo[LumiMessageSavedNotification.roleKey] as? String,
                  let role = LumiChatMessageRole(rawValue: roleRaw),
                  role == .user
            else {
                return
            }

            Task { @MainActor in
                handleSavedMessage(messageID: messageID, conversationID: conversationID)
            }
        }
    }

    private static func handleSavedMessage(messageID: UUID, conversationID: UUID) {
        guard let chatService = ConversationTitleRuntimeBridge.chatServiceProvider?(),
              let message = chatService.messages(for: conversationID).first(where: { $0.id == messageID })
        else {
            return
        }

        TitleOrchestrator.handleMessageSaved(message: message)
    }
}
