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
    /// 单个文本附件注入摘要的正文截断上限，避免一个附件挤占整段历史预算。
    public static let maxAttachmentTextChars = 1_500
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
        let history = Self.filteredMessages(await messages.messagesSnapshot(in: conversationID))
        guard !history.isEmpty else {
            return Outcome(summary: fallbackSummary(from: history), usedFallback: true)
        }

        do {
            let request = LLMRequest(
                conversationID: conversationID,
                modelID: conversations.modelID(for: conversationID).flatMap(LLMModelID.init(rawValue:)),
                messages: [
                    LLMMessage(role: .system, content: Self.summarySystemPrompt),
                    LLMMessage(
                        role: .user,
                        content: "Conversation to summarize:\n\n\(Self.renderHistory(history))"
                    ),
                ],
                model: nil
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

    static func filteredMessages(_ history: [Message]) -> [Message] {
        let visible = history
            .filter { $0.role == .user || $0.role == .assistant }
            .compactMap { message -> Message? in
                guard var text = summaryText(for: message) else { return nil }
                guard text.count > Self.maxCharsPerMessage else {
                    guard text != message.content else { return message }
                    var copy = message
                    copy.content = text
                    return copy
                }
                let head = text.prefix(Self.maxCharsPerMessage)
                text = "\(head)…[truncated]"
                var copy = message
                copy.content = text
                return copy
            }
        return Array(visible.suffix(Self.maxMessages))
    }

    /// 单条消息用于摘要的文字：正文非空，或带有已发送的附件时才算有效历史。
    ///
    /// 附件内容只做文字化描述，不把图片 base64 混入提示词；文本附件附带截断后的
    /// 正文，二进制附件给出文件名、类型和本地路径，避免附件里的需求被整体忽略。
    /// 没有附件时返回原始正文，保持既有截断行为不变。
    static func summaryText(for message: Message) -> String? {
        let attachments = attachmentDescriptions(from: message.metadata)
        let hasContent = !message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard hasContent || !attachments.isEmpty else { return nil }
        guard !attachments.isEmpty else { return message.content }

        let parts = ([message.content] + attachments)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return parts.joined(separator: "\n\n")
    }

    /// 把消息 metadata 中的附件渲染成摘要可用的文字。
    static func attachmentDescriptions(from metadata: [String: String]) -> [String] {
        guard !metadata.isEmpty else { return [] }

        var descriptions: [String] = []
        for image in UserAttachmentMetadata.decodeImageAttachments(from: metadata) {
            let name = image.fileName ?? image.mimeType
            descriptions.append("[Image attachment: \(name) (\(image.mimeType))]")
        }

        for file in UserAttachmentMetadata.decodeFileAttachments(from: metadata) {
            if let text = file.textContent?.trimmingCharacters(in: .whitespacesAndNewlines),
               !text.isEmpty {
                let body = text.count > Self.maxAttachmentTextChars
                    ? String(text.prefix(Self.maxAttachmentTextChars)) + "…[truncated]"
                    : text
                descriptions.append(
                    "[File attachment: \(file.fileName) (\(file.mimeType))]\n\(body)"
                )
            } else if let localPath = file.localPath, !localPath.isEmpty {
                descriptions.append(
                    "[Binary file attachment: \(file.fileName) (\(file.mimeType)), local path: \(localPath)]"
                )
            } else {
                descriptions.append(
                    "[Binary file attachment: \(file.fileName) (\(file.mimeType))]"
                )
            }
        }
        return descriptions
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
