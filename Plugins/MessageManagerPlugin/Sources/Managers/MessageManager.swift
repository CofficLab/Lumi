import Foundation
import LumiCoreMessage
import LumiKernel

/// Message Manager Service
///
/// Implements MessageManaging protocol with mock data for testing.
@MainActor
public final class MessageManager: ObservableObject, MessageManaging {
    /// Cache for generated mock messages (stable per conversation ID)
    private var mockMessageCache: [UUID: [LumiChatMessage]] = [:]

    private weak var kernel: LumiKernel?

    public init(kernel: LumiKernel) {
        self.kernel = kernel
    }

    /// Get the list of valid mock conversation IDs from kernel
    private var mockConversationIDs: [UUID] {
        kernel?.conversations?.mockConversationIDs() ?? []
    }

    /// Ensure mock messages exist for a conversation ID (only if it's in our mock conversation list)
    private func ensureMockMessages(for conversationID: UUID) {
        // Only generate messages for conversations that exist in our mock list
        guard mockConversationIDs.contains(conversationID) else { return }
        guard mockMessageCache[conversationID] == nil else { return }

        mockMessageCache[conversationID] = generateMockMessages(for: conversationID)
    }

    private func generateMockMessages(for conversationID: UUID) -> [LumiChatMessage] {
        // Generate stable mock messages based on conversation ID hash
        let baseTime = Date().addingTimeInterval(-3600)
        let hash = abs(conversationID.hashValue)

        return [
            LumiChatMessage(
                id: UUID(),
                conversationID: conversationID,
                role: .user,
                content: "Message 1 (conversation #\(hash % 1000))",
                createdAt: baseTime,
                providerID: "openai",
                modelName: "gpt-4",
                isError: false,
                renderKind: "text"
            ),
            LumiChatMessage(
                id: UUID(),
                conversationID: conversationID,
                role: .assistant,
                content: "Response 1 - How can I help you?",
                createdAt: baseTime.addingTimeInterval(60),
                providerID: "openai",
                modelName: "gpt-4",
                isError: false,
                renderKind: "text"
            ),
            LumiChatMessage(
                id: UUID(),
                conversationID: conversationID,
                role: .user,
                content: "Follow-up message #\(hash % 1000)",
                createdAt: baseTime.addingTimeInterval(120),
                providerID: "openai",
                modelName: "gpt-4",
                isError: false,
                renderKind: "text"
            ),
            LumiChatMessage(
                id: UUID(),
                conversationID: conversationID,
                role: .assistant,
                content: "Here's my response to your follow-up.",
                createdAt: baseTime.addingTimeInterval(180),
                providerID: "openai",
                modelName: "gpt-4",
                isError: false,
                renderKind: "text"
            ),
        ]
    }

    public func messages(for conversationID: UUID) -> [LumiChatMessage] {
        ensureMockMessages(for: conversationID)
        return mockMessageCache[conversationID] ?? []
    }

    public func deleteMessage(id: UUID, in conversationID: UUID) {
        mockMessageCache[conversationID]?.removeAll { $0.id == id }
    }

    public func insertMessage(_ message: LumiChatMessage, to conversationID: UUID) {
        // Only allow insert for valid mock conversations
        guard mockConversationIDs.contains(conversationID) else { return }
        ensureMockMessages(for: conversationID)
        var newMessage = message
        newMessage = LumiChatMessage(
            id: message.id,
            conversationID: conversationID,
            role: message.role,
            content: message.content,
            createdAt: message.createdAt,
            providerID: message.providerID,
            modelName: message.modelName,
            isError: message.isError,
            renderKind: message.renderKind
        )
        mockMessageCache[conversationID]?.append(newMessage)
    }

    public func updateMessage(id: UUID, in conversationID: UUID, content: String) {
        guard mockConversationIDs.contains(conversationID) else { return }
        ensureMockMessages(for: conversationID)
        if let index = mockMessageCache[conversationID]?.firstIndex(where: { $0.id == id }) {
            let old = mockMessageCache[conversationID]![index]
            mockMessageCache[conversationID]![index] = LumiChatMessage(
                id: old.id,
                conversationID: old.conversationID,
                role: old.role,
                content: content,
                createdAt: old.createdAt,
                providerID: old.providerID,
                modelName: old.modelName,
                isError: old.isError,
                renderKind: old.renderKind
            )
        }
    }

    public func clearMessages(in conversationID: UUID) {
        mockMessageCache[conversationID] = []
    }
}
