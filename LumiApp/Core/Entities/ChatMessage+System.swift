import Foundation

// MARK: - 内置系统消息占位键与工厂

extension ChatMessage {
    // MARK: 占位键

    static var loadingLocalModelSystemContentKey: String { "__LUMI_LOADING_LOCAL_MODEL__" }
    static var loadingLocalModelDoneSystemContentKey: String { "__LUMI_LOADING_LOCAL_MODEL_DONE__" }
    static var turnCompletedSystemContentKey: String { "__LUMI_TURN_COMPLETED__" }

    // MARK: 工厂

    static func makeAbortMessage(toolCallID: String?, conversationId: UUID) -> ChatMessage {
        ChatMessage(
            role: .tool,
            conversationId: conversationId,
            content: "[Tool execution aborted by safety guard]",
            toolCallID: toolCallID
        )
    }

    /// 达到最大深度时的最后一步提醒（作为一条 user 消息追加，用于提示模型不再调用工具、直接给出最终回答）。
    static func maxDepthFinalStepReminderMessage(conversationId: UUID) -> ChatMessage {
        ChatMessage(
            role: .user,
            conversationId: conversationId,
            content: """
            <system-reminder>
            You have reached the final execution step. Do not call any tools anymore.
            Provide your best final answer using the information already collected.
            If critical information is missing, explicitly state what is missing and ask one concise follow-up question.
            </system-reminder>
            """
        )
    }

    static func loadingLocalModelSystemMessage(
        languagePreference: LanguagePreference,
        conversationId: UUID,
        providerId: String? = nil,
        modelName: String? = nil
    ) -> ChatMessage {
        ChatMessage(
            role: .system,
            conversationId: conversationId,
            content: Self.loadingLocalModelSystemContentKey,
            providerId: providerId,
            modelName: modelName
        )
    }

    static func turnCompletedSystemMessage(languagePreference: LanguagePreference, conversationId: UUID) -> ChatMessage {
        ChatMessage(
            role: .status,
            conversationId: conversationId,
            content: Self.turnCompletedSystemContentKey
        )
    }
}
