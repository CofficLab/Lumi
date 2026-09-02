import Foundation
import ProviderConversation
import ProviderMessage
import ProviderLLMManager
import KitLLM

extension Message {
    var llmMessage: LLMMessage {
        LLMMessage(
            role: KitLLM.MessageRole(rawValue: role.rawValue) ?? .unknown,
            content: content,
            toolCalls: toolCalls?.map { LLMToolCall(id: $0.id, name: $0.name, arguments: $0.arguments) },
            toolCallID: toolCallID,
            reasoningContent: reasoningContent,
            images: []
        )
    }
}

/// 用当前对话的模型把历史浓缩成摘要，用于在新对话中续写。
///
/// 复刻自旧版 `ConversationSummarizer`：
/// - 优先调用 LLM 生成摘要（`LLMProviderManagerProviding.complete`）；
/// - provider 不可用或失败时回退为本地拼装的精简摘要，保证永不卡死。
public struct ConversationSummarizer: @unchecked Sendable {
    /// 单条消息正文的截断上限。
    public static let maxCharsPerMessage = 4_000
    /// 参与摘要的最大消息条数（取最近 N 条）。
    public static let maxMessages = 60

    public struct Outcome: Sendable, Equatable {
        public let summary: String
        public let usedFallback: Bool

        public init(summary: String, usedFallback: Bool) {
            self.summary = summary
            self.usedFallback = usedFallback
        }
    }

    private let conversations: any ConversationManaging
    private let messages: any MessageManaging
    private let llmProvider: any LLMManaging

    public init(
        conversations: any ConversationManaging,
        messages: any MessageManaging,
        llmProvider: any LLMManaging
    ) {
        self.conversations = conversations
        self.messages = messages
        self.llmProvider = llmProvider
    }

    @MainActor
    public func summarize(conversationID: UUID) async -> Outcome {
        let history = filteredMessages(await messages.messagesSnapshot(in: conversationID))
        guard !history.isEmpty else {
            return Outcome(summary: fallbackSummary(from: history), usedFallback: true)
        }

        do {
            let request = LLMRequest(
                conversationID: conversationID,
                messages: [
                    LLMMessage(role: .system, content: Self.summarySystemPrompt),
                    LLMMessage(
                        role: .user,
                        content: "Conversation to summarize:\n\n\(Self.renderHistory(history))"
                    ),
                ],
                model: conversations.modelName(for: conversationID)
            )
            let response = try await llmProvider.complete(request)
            let trimmed = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                return Outcome(summary: fallbackSummary(from: history), usedFallback: true)
            }
            return Outcome(summary: trimmed, usedFallback: false)
        } catch {
            return Outcome(summary: fallbackSummary(from: history), usedFallback: true)
        }
    }

    // MARK: - Private

    private func filteredMessages(_ history: [Message]) -> [Message] {
        let visible = history
            .filter { $0.role == .user || $0.role == .assistant }
            .filter { !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let recent = visible.suffix(Self.maxMessages)
        return Array(recent).map { message in
            guard message.content.count > Self.maxCharsPerMessage else { return message }
            let head = message.content.prefix(Self.maxCharsPerMessage)
            var truncated = message
            truncated.content = "\(head)…[truncated]"
            return truncated
        }
    }

    private func fallbackSummary(from history: [Message]) -> String {
        let userTurns = history
            .filter { $0.role == .user }
            .suffix(8)
            .map { "• \($0.content.trimmingCharacters(in: .whitespacesAndNewlines))" }
        let lastAssistant = history
            .last(where: { $0.role == .assistant })?
            .content
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(800)

        var lines: [String] = []
        if !userTurns.isEmpty {
            lines.append("Recent requests:")
            lines.append(contentsOf: userTurns)
        }
        if let lastAssistant, !lastAssistant.isEmpty {
            lines.append("")
            lines.append("Last assistant response:")
            lines.append(String(lastAssistant))
        }
        if lines.isEmpty {
            return "(No prior context captured.)"
        }
        return lines.joined(separator: "\n")
    }

    static let summarySystemPrompt = """
    You are a conversation summarizer. Produce a compact but complete summary of the conversation that captures:
    - The user's goal and any constraints
    - Key decisions, findings, and code changes
    - Open questions or next steps
    Keep the summary under 400 words. Write it in the language of the conversation.
    """

    nonisolated static func renderHistory(_ messages: [Message]) -> String {
        messages.map { message in
            let prefix = message.role == .user ? "User" : "Assistant"
            return "\(prefix): \(message.content)"
        }.joined(separator: "\n\n")
    }
}
