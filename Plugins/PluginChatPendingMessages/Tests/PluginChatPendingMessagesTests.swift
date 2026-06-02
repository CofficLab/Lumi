import Foundation
import Testing
import LumiCoreKit
@testable import PluginChatPendingMessages

@MainActor
@Test func windowConversationVMProvidesAndRemovesPendingMessages() {
    let selectedConversationId = UUID()
    let selectedMessageId = UUID()
    let otherConversationId = UUID()
    let selectedMessage = ChatMessage(
        id: selectedMessageId,
        role: .user,
        conversationId: selectedConversationId,
        content: "queued for selected conversation",
        timestamp: Date(timeIntervalSince1970: 1),
        queueStatus: .pending
    )
    let otherMessage = ChatMessage(
        id: UUID(),
        role: .user,
        conversationId: otherConversationId,
        content: "queued elsewhere",
        timestamp: Date(timeIntervalSince1970: 2),
        queueStatus: .pending
    )
    var removedMessageIds: [UUID] = []

    let conversationVM = WindowConversationVM(
        selectedConversationId: selectedConversationId,
        pendingMessagesProvider: { conversationId in
            conversationId == selectedConversationId ? [selectedMessage] : [otherMessage]
        },
        pendingMessageRemover: { messageId in
            removedMessageIds.append(messageId)
        }
    )

    #expect(conversationVM.currentPendingMessages() == [selectedMessage])

    conversationVM.selectedConversationId = otherConversationId
    #expect(conversationVM.currentPendingMessages() == [otherMessage])

    conversationVM.removePendingMessage(id: selectedMessageId)
    #expect(removedMessageIds == [selectedMessageId])

    let version = conversationVM.pendingMessagesVersion
    conversationVM.notifyPendingMessagesChanged()
    #expect(conversationVM.pendingMessagesVersion == version + 1)
}
