import Testing
import Foundation
@testable import HistoryDBStatusBarPlugin
@testable import LumiKernel

// MARK: - Test Fixtures

extension HistoryMessageRow {
    static func fixture(
        id: UUID = UUID(),
        conversationId: UUID = UUID(),
        conversationTitle: String = "Test Conversation",
        role: String = "user",
        model: String = "gpt-4o",
        tokens: Int = 100,
        timestamp: Date = Date(),
        contentPreview: String = "Hello world"
    ) -> HistoryMessageRow {
        HistoryMessageRow(
            id: id,
            conversationId: conversationId,
            conversationTitle: conversationTitle,
            role: role,
            model: model,
            tokens: tokens,
            timestamp: timestamp,
            contentPreview: contentPreview
        )
    }
}

extension HistoryConversationRow {
    static func fixture(
        id: UUID = UUID(),
        title: String = "Test Conversation",
        projectId: String = "/test/project",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        messageCount: Int = 5,
        providerId: String? = "openai",
        model: String? = "gpt-4o",
        chatMode: String? = "build"
    ) -> HistoryConversationRow {
        HistoryConversationRow(
            id: id,
            title: title,
            projectId: projectId,
            createdAt: createdAt,
            updatedAt: updatedAt,
            messageCount: messageCount,
            providerId: providerId,
            model: model,
            chatMode: chatMode
        )
    }
}
