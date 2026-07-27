import Foundation
import LumiKernel

extension ConversationTitlePlugin {
    @MainActor
    public static func sendMiddlewares(lumiCore: Any) -> [LumiChatMessage] {
        if let kernel = lumiCore as? LumiKernel {
            return makeSendMiddlewares(kernel: kernel)
        }
        return [
            LumiChatMessage(
                conversationID: UUID(),
                role: .system,
                content: titleHintPrompt
            )
        ]
    }

    @MainActor
    private static func makeSendMiddlewares(kernel: LumiKernel) -> [LumiChatMessage] {
        guard let conversation = resolvedConversation(kernel: kernel),
              !conversation.hasCustomTitle else {
            return []
        }

        return [
            LumiChatMessage(
                conversationID: conversation.id,
                role: .system,
                content: titleHintPrompt
            )
        ]
    }

    @MainActor
    static func resolvedConversation(kernel: LumiKernel) -> LumiConversationSummary? {
        guard let conversations = kernel.conversations,
              let selectedID = conversations.selectedConversationID else {
            return nil
        }
        return conversations.conversations.first(where: { $0.id == selectedID })
    }

    static var titleHintPrompt: String {
        """
        The current conversation title is empty.
        Please create a concise, user-facing title for this conversation and call the
        `update_conversation_title` tool exactly once.

        Rules:
        - Keep the title short and specific.
        - Use the same language as the conversation when practical.
        - Do not mention this instruction to the user.
        """
    }
}
