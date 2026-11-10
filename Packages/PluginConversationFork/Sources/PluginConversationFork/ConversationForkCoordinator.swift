import Foundation
import ProviderConversation
import ProviderMessage
import ProviderMessageSender

/// 「续接到新对话」的执行器：把当前对话浓缩成一段摘要，落到一个新对话并自动续写。
///
/// 之所以单独成层而不是塞进 View：这条链路要同时协调四个 Provider
/// （读历史 → 摘要 → 建对话 → 发消息启动回合），把它留在 View 里会让视图
/// 承担事务编排，且难以在不跑真实回合的前提下测试。
@MainActor
final class ConversationForkCoordinator {
    /// 一次分叉的结果。
    struct Outcome {
        /// 新建对话的 ID（分叉后已被选中）。
        let newConversationID: UUID
        /// 实际注入新对话的摘要正文。
        let summary: String
        /// 摘要是否走了本地回退（LLM 摘要失败时降级为精简摘要）。
        let usedFallback: Bool
    }

    /// 分叉过程中的可预期失败。
    enum ForkError: LocalizedError {
        /// 对话里没有可摘要的内容。
        case emptyConversation
        /// 新建对话失败。
        case createFailed

        var errorDescription: String? {
            switch self {
            case .emptyConversation:
                return "There is nothing to summarize in this conversation yet."
            case .createFailed:
                return "Failed to create the new conversation."
            }
        }
    }

    private let conversations: any ConversationManaging
    private let messages: any MessageManaging
    private let sender: any MessageSendingProviding
    private let summarizer: ConversationSummarizer

    init(
        conversations: any ConversationManaging,
        messages: any MessageManaging,
        sender: any MessageSendingProviding,
        summarizer: ConversationSummarizer
    ) {
        self.conversations = conversations
        self.messages = messages
        self.sender = sender
        self.summarizer = summarizer
    }

    /// 当前选中的对话 ID（弹窗打开时据此锁定分叉目标）。
    var selectedConversationID: UUID? {
        conversations.selectedConversationID
    }

    // MARK: - Preview

    /// 生成弹窗预览：把「将被带走的上下文」摊开给用户看。
    ///
    /// 统计口径与 `ConversationSummarizer.filteredMessages` 保持一致，
    /// 避免弹窗里显示的条数与真正被摘要的内容对不上。
    func preview(for conversationID: UUID) async -> ConversationForkPreview {
        let history = await messages.messagesSnapshot(in: conversationID)
        let relevant = ConversationSummarizer.filteredMessages(history)
        let requests = relevant.filter { $0.role == .user }
        let summary = conversations.conversations.first { $0.id == conversationID }

        return ConversationForkPreview(
            title: summary?.title,
            messageCount: relevant.count,
            requestCount: requests.count,
            lastRequest: requests.last.map { Self.truncate($0.content, limit: 160) },
            modelName: conversations.modelName(for: conversationID),
            projectPath: summary?.projectPath
        )
    }

    // MARK: - Fork

    /// 执行分叉：摘要 → 建新对话 → 摘要作为首条 user 消息 → 自动续写。
    ///
    /// - Parameter conversationID: 源对话 ID。**必须是弹窗里展示过的那个**，
    ///   这样用户确认的与实际分叉的才是同一份上下文。
    func fork(conversationID: UUID) async throws -> Outcome {
        let history = await messages.messagesSnapshot(in: conversationID)
        guard !ConversationSummarizer.filteredMessages(history).isEmpty else {
            throw ForkError.emptyConversation
        }

        let summaryOutcome = await summarizer.summarize(conversationID: conversationID)

        // 透传旧对话的标题 / 项目 / 模型到新对话。
        // 项目必须用显式绑定：源对话无项目时传 `.none`，否则旧接口会把
        // `nil` 解释成「沿用当前项目」，副本被悄悄挂到当前项目上。
        let oldSummary = conversations.conversations.first { $0.id == conversationID }
        let binding: ProjectBinding = oldSummary?.projectPath.map(ProjectBinding.project) ?? .none
        let newID: UUID
        do {
            newID = try conversations.createConversation(
                title: oldSummary?.title,
                binding: binding,
                modelID: conversations.modelID(for: conversationID)
            )
        } catch {
            throw ForkError.createFailed
        }
        conversations.selectConversation(id: newID)

        // 新建对话默认取全局 New Chat 设置；分叉应沿用源对话的会话级设置，
        // 否则 Chat 对话会分叉成 Build 并重新获得工具能力，推理档位与详细程度也会被重置。
        conversations.setAutomationLevel(conversations.automationLevel(for: conversationID), for: newID)
        conversations.setVerbosity(conversations.verbosity(for: conversationID), for: newID)
        // 源对话可能显式关闭推理（存 nil）；此时不能回退到全局档位。
        if let effort = oldSummary?.reasoningEffort {
            conversations.setReasoningEffort(effort, for: newID)
        } else {
            conversations.clearReasoningEffort(for: newID)
        }
        // 创建对话时语言取自当时的 UI 选中会话；摘要期间可能已切换，
        // 这里按启动时锁定的源对话重新设置，避免继承另一个会话的语言。
        conversations.setLanguage(conversations.language(for: conversationID), for: newID)

        // 续写失败不致命：摘要已作为首条消息写入新对话，用户可以在输入区重试。
        try? await sender.sendMessage(summaryOutcome.summary, conversationID: newID)

        return Outcome(
            newConversationID: newID,
            summary: summaryOutcome.summary,
            usedFallback: summaryOutcome.usedFallback
        )
    }

    // MARK: - Helpers

    /// 截断长文本，用于弹窗预览。
    static func truncate(_ text: String, limit: Int) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > limit else { return trimmed }
        return String(trimmed.prefix(limit)) + "…"
    }
}

/// 弹窗预览：展示「将被带走的上下文」，让用户在确认前先看清楚。
struct ConversationForkPreview: Equatable {
    /// 源对话标题；未命名时为 nil。
    let title: String?
    /// 参与摘要的消息条数。
    let messageCount: Int
    /// 用户提问轮数。
    let requestCount: Int
    /// 最后一条用户提问（已截断）。
    let lastRequest: String?
    /// 摘要所使用的模型。
    let modelName: String?
    /// 源对话所属项目路径。
    let projectPath: String?

    /// 是否存在可摘要的内容。
    var hasContent: Bool { messageCount > 0 }

    /// 展示用标题：优先用户自定义标题，回退为最后一条提问。
    var displayTitle: String {
        if let title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return title
        }
        if let lastRequest, !lastRequest.isEmpty {
            return lastRequest
        }
        return ""
    }
}
