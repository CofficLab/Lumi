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
    /// 单次工具调用的参数截断上限。
    public static let maxToolArgumentChars = 800
    /// 单条工具结果的截断上限，避免大型输出挤占整段历史预算。
    public static let maxToolResultChars = 1_500
    /// 回退摘要中保留的最近工具事件数。
    public static let maxToolEvents = 12
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
        let toolNames = toolNamesByCallID(history)
        let visible = history
            .filter { $0.role == .user || $0.role == .assistant || $0.role == .tool }
            .compactMap { message -> Message? in
                guard var text = summaryText(for: message, toolNames: toolNames) else { return nil }
                // 工具结果单独限流：一次命令输出可能远大于普通正文。
                let limit = message.role == .tool ? Self.maxToolResultChars : Self.maxCharsPerMessage
                guard text.count > limit else {
                    guard text != message.content else { return message }
                    var copy = message
                    copy.content = text
                    return copy
                }
                let head = text.prefix(limit)
                text = "\(head)…[truncated]"
                var copy = message
                copy.content = text
                return copy
            }
        return Array(visible.suffix(Self.maxMessages))
    }

    /// 工具调用 ID 到工具名的映射，用于给工具结果标注来源。
    static func toolNamesByCallID(_ history: [Message]) -> [String: String] {
        var names: [String: String] = [:]
        for message in history {
            for call in message.toolCalls ?? [] {
                names[call.id] = call.name
            }
        }
        return names
    }

    /// 单条消息用于摘要的文字：正文非空，或带有已发送的附件、工具调用时才算有效历史。
    ///
    /// 附件内容只做文字化描述，不把图片 base64 混入提示词；文本附件附带截断后的
    /// 正文，二进制附件给出文件名、类型和本地路径，避免附件里的需求被整体忽略。
    /// 工具调用与工具结果同样文字化，使关键发现、修改和失败原因能延续到新对话。
    /// 没有附件时返回原始正文，保持既有截断行为不变。
    static func summaryText(
        for message: Message,
        toolNames: [String: String] = [:]
    ) -> String? {
        let attachments = attachmentDescriptions(from: message.metadata)
        let hasContent = !message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        var parts: [String] = []
        if hasContent {
            parts.append(message.content)
        }
        parts.append(contentsOf: attachments)

        if message.role == .tool {
            let name = message.toolCallID.flatMap { toolNames[$0] }
            let label = name.map { "[Tool result for \($0)]" } ?? "[Tool result]"
            parts.insert(label, at: 0)
        }
        if let toolCalls = message.toolCalls, !toolCalls.isEmpty {
            parts.append(contentsOf: toolCalls.map(toolCallDescription))
        }

        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: "\n\n")
    }

    /// 一次工具调用的文字化描述，参数按上限截断。
    static func toolCallDescription(_ call: MessageToolCall) -> String {
        let arguments = call.arguments.count > Self.maxToolArgumentChars
            ? String(call.arguments.prefix(Self.maxToolArgumentChars)) + "…[truncated]"
            : call.arguments
        return "[Tool call: \(call.name)]\n\(arguments)"
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
        // 工具动作往往承载唯一发现、修改或失败原因，回退摘要也要带上最近几条。
        let toolEvents = history
            .filter { $0.role == .tool || !($0.toolCalls ?? []).isEmpty }
            .suffix(Self.maxToolEvents)
            .compactMap { message -> String? in
                let text = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { return nil }
                let bounded = text.count > 300 ? String(text.prefix(300)) + "…" : text
                return "• \(bounded)"
            }

        var lines: [String] = []
        if !userTurns.isEmpty {
            lines.append("Recent requests:")
            lines.append(contentsOf: userTurns)
        }
        if !toolEvents.isEmpty {
            lines.append("")
            lines.append("Recent tool activity:")
            lines.append(contentsOf: toolEvents)
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
            let prefix: String
            switch message.role {
            case .user:
                prefix = "User"
            case .tool:
                prefix = "Tool"
            default:
                prefix = "Assistant"
            }
            return "\(prefix): \(message.content)"
        }.joined(separator: "\n\n")
    }
}
