import Foundation
import SwiftUI

/// 按会话维护一条「当前发送/流式/工具」状态，用 `ChatMessage`（`role == .status`）表示，不持久化、不发给 LLM。
@MainActor
final class ConversationSendStatusVM: ObservableObject {
    @Published private(set) var statusMessageByConversationId: [UUID: ChatMessage] = [:]

    private var stableStatusRowIdByConversationId: [UUID: UUID] = [:]
    /// 当前流式响应内累积的思考文本（按会话），用于状态行展示。
    private var thinkingTextBufferByConversationId: [UUID: String] = [:]
    /// 当前流式响应内累积的正文（按会话），用于状态行展示尾部预览。
    private var streamingTextBufferByConversationId: [UUID: String] = [:]

    /// 当前会话的状态消息（若有）。
    func statusMessage(for conversationId: UUID) -> ChatMessage? {
        statusMessageByConversationId[conversationId]
    }

    func setStatus(conversationId: UUID, content: String) {
        let rowId = stableStatusRowIdByConversationId[conversationId] ?? {
            let id = UUID()
            stableStatusRowIdByConversationId[conversationId] = id
            return id
        }()
        statusMessageByConversationId[conversationId] = ChatMessage(
            id: rowId,
            role: .status,
            content: content,
            timestamp: Date(),
            isTransientStatus: true
        )
    }

    func clearStatus(conversationId: UUID) {
        statusMessageByConversationId[conversationId] = nil
        stableStatusRowIdByConversationId[conversationId] = nil
        thinkingTextBufferByConversationId[conversationId] = nil
        streamingTextBufferByConversationId[conversationId] = nil
    }

    /// 状态行：标题 + 尾部预览（换行压成空格、最多 30 字）；无尾部时为 `title...`。
    private static func statusLineWithTailPreview(accumulated: String, title: String) -> String {
        let normalized = accumulated.split(whereSeparator: \.isNewline).joined(separator: " ")
        let previewMax = 30
        let tail = normalized.isEmpty
            ? ""
            : (normalized.count <= previewMax ? normalized : String(normalized.suffix(previewMax)))
        if tail.isEmpty {
            return "\(title)..."
        }
        return "\(title)：\(tail)"
    }

    /// 根据流式分片更新状态文案
    func applyStreamChunk(conversationId: UUID, chunk: StreamChunk) {
        // 结束
        if chunk.isDone {
            thinkingTextBufferByConversationId[conversationId] = nil
            streamingTextBufferByConversationId[conversationId] = nil
            setStatus(conversationId: conversationId, content: "结束")
            return
        }

        // 思考
        if chunk.isThinking() {
            thinkingTextBufferByConversationId[conversationId, default: ""] += chunk.getContent()
        
            let accumulated = thinkingTextBufferByConversationId[conversationId] ?? ""
            let line = Self.statusLineWithTailPreview(accumulated: accumulated, title: chunk.getTitle())
            setStatus(conversationId: conversationId, content: line)
            return
        }

        // 正文
        if chunk.isReceivingContent() {
            streamingTextBufferByConversationId[conversationId, default: ""] += chunk.getContent()
            let accumulated = streamingTextBufferByConversationId[conversationId] ?? ""
            let line = Self.statusLineWithTailPreview(accumulated: accumulated, title: chunk.getTitle())
            setStatus(conversationId: conversationId, content: line)
            return
        }

        let typeStr = chunk.getTitle()
        setStatus(conversationId: conversationId, content: "\(typeStr)...")
    }
}
