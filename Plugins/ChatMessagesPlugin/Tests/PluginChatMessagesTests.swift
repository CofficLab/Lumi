import Foundation
import Testing
import LumiCoreKit
@testable import ChatMessagesPlugin

@MainActor
@Test func windowConversationVMProvidesSelectedConversationMessages() {
    let selectedConversationId = UUID()
    let otherConversationId = UUID()
    let selectedMessage = ChatMessage(
        id: UUID(),
        role: .user,
        conversationId: selectedConversationId,
        content: "selected conversation",
        timestamp: Date(timeIntervalSince1970: 1)
    )
    let otherMessage = ChatMessage(
        id: UUID(),
        role: .assistant,
        conversationId: otherConversationId,
        content: "other conversation",
        timestamp: Date(timeIntervalSince1970: 2)
    )

    let conversationVM = WindowConversationVM(
        selectedConversationId: selectedConversationId,
        messagesProvider: { conversationId in
            conversationId == selectedConversationId ? [selectedMessage] : [otherMessage]
        }
    )

    #expect(conversationVM.hasSelectedConversation)
    #expect(conversationVM.currentMessages() == [selectedMessage])

    conversationVM.selectedConversationId = otherConversationId
    #expect(conversationVM.currentMessages() == [otherMessage])

    conversationVM.selectedConversationId = nil
    #expect(!conversationVM.hasSelectedConversation)
    #expect(conversationVM.currentMessages().isEmpty)
}

@MainActor
@Test func windowConversationVMAppendsSelectedConversationStatusMessage() {
    let selectedConversationId = UUID()
    let selectedMessage = ChatMessage(
        id: UUID(),
        role: .user,
        conversationId: selectedConversationId,
        content: "selected conversation",
        timestamp: Date(timeIntervalSince1970: 1)
    )
    let statusMessage = ChatMessage(
        id: UUID(),
        role: .status,
        conversationId: selectedConversationId,
        content: "正在发送消息…",
        timestamp: Date(timeIntervalSince1970: 2),
        isTransientStatus: true
    )

    let conversationVM = WindowConversationVM(
        selectedConversationId: selectedConversationId,
        messagesProvider: { _ in [selectedMessage] },
        statusMessageProvider: { conversationId in
            conversationId == selectedConversationId ? statusMessage : nil
        }
    )

    #expect(conversationVM.currentMessages() == [selectedMessage])
    #expect(conversationVM.currentDisplayMessages() == [selectedMessage, statusMessage])
}
