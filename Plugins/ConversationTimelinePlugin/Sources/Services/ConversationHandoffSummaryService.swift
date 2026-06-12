import Foundation
import LumiCoreKit
import LLMKit

public struct ConversationHandoffSummaryService {
    public typealias MessageSender = @Sendable ([ChatMessage], LLMConfig) async throws -> ChatMessage

    private let maxSourceCharacters = 24_000

    public func summarize(messages: [ChatMessage], config: LLMConfig, sendMessage: MessageSender) async throws -> String {
        let transcript = transcript(from: messages)
        guard !transcript.isEmpty else {
            throw ConversationHandoffSummaryError.emptyConversation
        }

        let prompt = """
        请把下面的聊天记录总结成一份可用于开启新对话的上下文交接摘要。

        要求：
        - 使用中文
        - 保留用户目标、已经完成的工作、关键决策、未解决问题和下一步建议
        - 如果涉及代码或文件路径，保留具体名称
        - 不要加入聊天记录中没有出现的信息
        - 输出 Markdown，控制在 800 字以内

        聊天记录：
        \(transcript)
        """

        let request = ChatMessage(role: .user, conversationId: UUID(), content: prompt)
        let response = try await sendMessage([request], config)
        let summary = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !summary.isEmpty else {
            throw ConversationHandoffSummaryError.emptySummary
        }
        return summary
    }

    public func handoffMessage(from summary: String) -> String {
        """
        以下是上一段对话的上下文摘要，请在后续回复中沿用这份背景：

        \(summary)
        """
    }

    private func transcript(from messages: [ChatMessage]) -> String {
        let sendableMessages = messages
            .filter { $0.role == .user || $0.role == .assistant }
            .filter { !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        var remaining = maxSourceCharacters
        var selected: [String] = []

        for message in sendableMessages.reversed() {
            let rendered = render(message)
            guard !rendered.isEmpty else { continue }

            if rendered.count <= remaining {
                selected.append(rendered)
                remaining -= rendered.count
            } else if remaining > 1_000 {
                selected.append(String(rendered.suffix(remaining)))
                break
            } else {
                break
            }
        }

        return selected.reversed().joined(separator: "\n\n")
    }

    private func render(_ message: ChatMessage) -> String {
        let role: String
        switch message.role {
        case .user:
            role = "User"
        case .assistant:
            role = "Assistant"
        default:
            return ""
        }

        let content = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return "" }
        return "\(role):\n\(content)"
    }
}

public enum ConversationHandoffSummaryError: LocalizedError {
    case emptyConversation
    case emptySummary
    case missingConversation
    case missingModel

    public var errorDescription: String? {
        switch self {
        case .emptyConversation:
            return "当前对话没有可总结的聊天内容"
        case .emptySummary:
            return "模型没有返回摘要内容"
        case .missingConversation:
            return "当前没有选中的对话"
        case .missingModel:
            return "当前模型配置不可用"
        }
    }
}
