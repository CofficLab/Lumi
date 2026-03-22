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

    /// 根据流式分片更新状态文案
    func applyStreamChunk(conversationId: UUID, chunk: StreamChunk) {
        if chunk.isDone {
            thinkingTextBufferByConversationId[conversationId] = nil
            streamingTextBufferByConversationId[conversationId] = nil
            setStatus(conversationId: conversationId, content: "流式响应结束")
            return
        }
        if chunk.eventType == .thinkingDelta {
            if let partial = chunk.content, !partial.isEmpty {
                thinkingTextBufferByConversationId[conversationId, default: ""] += partial
            }
            let accumulated = thinkingTextBufferByConversationId[conversationId] ?? ""
            let previewMax = 20
            let tail = accumulated.isEmpty
                ? ""
                : (accumulated.count <= previewMax ? accumulated : String(accumulated.suffix(previewMax)))
            let line: String
            if tail.isEmpty {
                line = "正在思考…"
            } else {
                line = "正在思考：\(tail)"
            }
            setStatus(conversationId: conversationId, content: line)
            return
        }
        if chunk.eventType == .textDelta {
            if let partial = chunk.content, !partial.isEmpty {
                streamingTextBufferByConversationId[conversationId, default: ""] += partial
            }
            let accumulated = streamingTextBufferByConversationId[conversationId] ?? ""
            let previewMax = 20
            let tail = accumulated.isEmpty
                ? ""
                : (accumulated.count <= previewMax ? accumulated : String(accumulated.suffix(previewMax)))
            let line: String
            if tail.isEmpty {
                line = "正在生成消息..."
            } else {
                line = "正在生成消息... \(tail)"
            }
            setStatus(conversationId: conversationId, content: line)
            return
        }
        let typeStr = chunk.eventType?.rawValue ?? "stream"
        var line = "[\(typeStr)]"
        if let partial = chunk.content, !partial.isEmpty {
            line += " \(String(partial.prefix(64)))"
        }
        setStatus(conversationId: conversationId, content: line)
    }
}
