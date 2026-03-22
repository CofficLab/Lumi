import Foundation
import SwiftUI

/// 按会话维护一条「当前发送/流式/工具」状态，用 `ChatMessage`（`role == .status`）表示，不持久化、不发给 LLM。
@MainActor
final class ConversationSendStatusVM: ObservableObject {
    @Published private(set) var statusMessageByConversationId: [UUID: ChatMessage] = [:]

    private var stableStatusRowIdByConversationId: [UUID: UUID] = [:]

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
    }

    /// 根据流式分片更新状态文案（供 `Sendable` 闭包内 `MainActor.run` 调用）。
    func applyStreamChunk(conversationId: UUID, chunk: StreamChunk) {
        if chunk.isDone {
            setStatus(conversationId: conversationId, content: "流式响应结束")
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
