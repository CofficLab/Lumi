import Foundation
import LumiCoreKit

/// 用当前对话的模型把历史浓缩成摘要，用于在新对话中续写。
///
/// 优先调用 `LumiChatServicing.generateEphemeralCompletion`（不写入任何对话历史）；
/// 若 provider 不可用或请求失败，回退为本地拼装的精简摘要，保证「一键续接」永不卡死。
public struct ConversationSummarizer {
    /// 单条消息正文的截断上限，避免把过长的历史喂给摘要请求。
    ///
    /// 摘要请求会拼接所有可见消息；这里给每条一个宽松上限，
    /// 防止一条超长的工具输出 / 代码块撑爆摘要请求的上下文。
    public static let maxCharsPerMessage = 4_000

    /// 参与摘要的最大消息条数（取最近 N 条）。
    public static let maxMessages = 60

    /// 摘要结果。
    public struct Outcome: Sendable, Equatable {
        /// 最终用于续写的摘要文本。
        public let summary: String
        /// 是否走了本地回退（而非模型生成）。
        public let usedFallback: Bool
    }

    public init() {}

    /// 生成给定对话的续写摘要。
    ///
    /// - Parameters:
    ///   - conversationID: 当前对话 ID（用于解析 provider / model）。
    ///   - chatService: 聊天服务。
    /// - Returns: 摘要 + 是否走了回退。
    @MainActor
    public func summarize(
        conversationID: UUID,
        chatService: any LumiChatServicing
    ) async -> Outcome {
        let messages = filteredMessages(chatService.messages(for: conversationID))

        // 没有可见历史时无需调用模型，直接给一个最小的回退摘要。
        guard !messages.isEmpty else {
            return Outcome(summary: fallbackSummary(from: messages), usedFallback: true)
        }

        // 没有 provider / model 时无法调用模型，直接回退。
        guard let model = chatService.modelName(for: conversationID),
              chatService.providerID(for: conversationID) != nil
        else {
            return Outcome(summary: fallbackSummary(from: messages), usedFallback: true)
        }

        let summaryMessages = buildSummaryRequest(from: messages, conversationID: conversationID)

        do {
            let response = try await chatService.generateEphemeralCompletion(
                messages: summaryMessages,
                model: model,
                conversationID: conversationID
            )
            let trimmed = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            // 模型返回空内容时也走回退，避免把空摘要注入新对话。
            if trimmed.isEmpty {
                return Outcome(summary: fallbackSummary(from: messages), usedFallback: true)
            }
            return Outcome(summary: trimmed, usedFallback: false)
        } catch {
            return Outcome(summary: fallbackSummary(from: messages), usedFallback: true)
        }
    }

    // MARK: - Private

    /// 过滤出参与摘要的可见消息：仅保留 user / assistant，排除工具状态、错误等。
    /// 同时截断每条正文，并只保留最近 `maxMessages` 条。
    private func filteredMessages(_ messages: [LumiChatMessage]) -> [LumiChatMessage] {
        let visible = messages.filter { $0.role == .user || $0.role == .assistant }
            .filter { !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        let recent = visible.suffix(Self.maxMessages)
        return Array(recent).map { message in
            guard message.content.count > Self.maxCharsPerMessage else { return message }
            // 截断超长正文，保留首部并在尾部标注省略。
            let head = message.content.prefix(Self.maxCharsPerMessage)
            return LumiChatMessage(
                id: message.id,
                conversationID: message.conversationID,
                role: message.role,
                content: "\(head)…[truncated]",
                createdAt: message.createdAt,
                providerID: message.providerID,
                modelName: message.modelName,
                isError: message.isError,
                rawErrorDetail: message.rawErrorDetail,
                renderKind: message.renderKind,
                metadata: message.metadata,
                toolCalls: message.toolCalls,
                toolCallID: message.toolCallID,
                reasoningContent: message.reasoningContent
            )
        }
    }

    /// 构造摘要请求的消息数组：一条 system 指令 + 一条引用了历史的 user 消息。
    private func buildSummaryRequest(
        from messages: [LumiChatMessage],
        conversationID: UUID
    ) -> [LumiChatMessage] {
        let history = ForkPromptTemplates.renderHistory(messages)
        let userContent = "Conversation to summarize:\n\n\(history)"

        return [
            LumiChatMessage(
                conversationID: conversationID,
                role: .system,
                content: ForkPromptTemplates.summarySystemPrompt
            ),
            LumiChatMessage(
                conversationID: conversationID,
                role: .user,
                content: userContent
            )
        ]
    }

    /// 本地拼装的精简摘要：取最近若干条 user 消息 + 最后一条 assistant 消息。
    /// 用于模型不可用 / 失败时的回退，保证总能把关键上下文带到新对话。
    private func fallbackSummary(from messages: [LumiChatMessage]) -> String {
        let userTurns = messages
            .filter { $0.role == .user }
            .suffix(8)
            .map { "• \($0.content.trimmingCharacters(in: .whitespacesAndNewlines))" }
        let lastAssistant = messages
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
}
