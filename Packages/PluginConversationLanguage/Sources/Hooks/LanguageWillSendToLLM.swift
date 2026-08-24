import Foundation
import KernelLumi

/// Language willSendToLLM hook.
///
/// Adds the selected response language instruction as a transient system
/// message. AgentTurnRunner later merges system fragments before sending the
/// provider request, so this prompt is never persisted in the conversation.
@MainActor
public struct LanguageWillSendToLLMHook {
    private static let promptMarker = "languagePrompt"

    public init() {}

    public func execute(
        kernel: KernelLumi,
        messages: [LumiChatMessage]
    ) async -> [LumiChatMessage] {
        let conversationID = messages.first?.conversationID
            ?? kernel.conversations?.selectedConversationID

        guard conversationID != nil else { return messages }

        // 优先使用对话级别的语言偏好；无选中对话时回退到全局设置
        let language: LumiConversationLanguage = {
            guard let conversations = kernel.conversations else {
                return .chinese
            }
            if let conversationID,
               conversations.selectedConversationID == conversationID {
                return conversations.language(for: conversationID)
            }
            return conversations.globalLanguage
        }()

        let withoutPreviousPrompt = messages.filter {
            $0.metadata[Self.promptMarker] != "true"
        }

        let prompt = LumiChatMessage(
            conversationID: conversationID!,
            role: .system,
            content: Self.languagePrompt(for: language),
            metadata: [Self.promptMarker: "true"]
        )

        return [prompt] + withoutPreviousPrompt
    }

    static func languagePrompt(for language: LumiConversationLanguage) -> String {
        switch language {
        case .chinese:
            return """
            ## Response Language: 中文
            Reply to the user in Simplified Chinese (简体中文). All explanations, code comments, and documentation should be in Chinese.
            """
        case .english:
            return """
            ## Response Language: English
            Reply to the user in English. All explanations, code comments, and documentation should be in English.
            """
        }
    }
}
