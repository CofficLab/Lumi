import Foundation
import SwiftUI

/// 消息去重覆盖层
///
/// 挂载在根视图上，通过 `@EnvironmentObject` 获取 `ChatHistoryVM`，
/// 监听 `.messageSaved` 事件，对同一会话中内容完全一致的消息执行去重。
struct MessageDedupOverlay<Content: View>: View {
    let content: Content

    @EnvironmentObject private var chatHistoryVM: ChatHistoryVM

    var body: some View {
        content
            .onMessageSaved { message, conversationId in
                handleDedup(conversationId: conversationId)
            }
    }

    // MARK: - Dedup

    private func handleDedup(conversationId: UUID) {
        Task {
            guard let messages = await chatHistoryVM.loadMessagesAsync(forConversationId: conversationId),
                  messages.count > 1 else { return }

            // 按「内容签名」分组
            var groups: [MessageContentSignature: [ChatMessage]] = [:]
            for message in messages {
                let sig = MessageContentSignature(from: message)
                groups[sig, default: []].append(message)
            }

            // 收集需要删除的消息 ID（每组保留最早的一条，删除其余）
            var toDeleteIds: [UUID] = []
            for (_, group) in groups where group.count > 1 {
                // 按时间升序排列，保留第一条
                let sorted = group.sorted { $0.timestamp < $1.timestamp }
                let duplicates = sorted.dropFirst()
                toDeleteIds.append(contentsOf: duplicates.map(\.id))
            }

            guard !toDeleteIds.isEmpty else { return }

            let deleted = await chatHistoryVM.deleteMessagesAsync(
                messageIds: toDeleteIds,
                conversationId: conversationId
            )

            if deleted > 0 {
                AppLogger.core.info("🧹 [\(conversationId)] 去重完成：删除了 \(deleted) 条重复消息")
            }
        }
    }
}

// MARK: - Content Signature

/// 消息内容签名，用于判断两条消息内容是否一致。
///
/// 忽略 `id`、`timestamp`、`queueStatus`、`isTransientStatus` 以及性能指标等字段，
/// 只关注消息的「业务内容」是否相同。
private struct MessageContentSignature: Hashable {
    let role: MessageRole
    let content: String
    let isError: Bool
    let toolCallID: String?
    /// 将 toolCalls 序列化为确定性 JSON 字符串用于比较
    let toolCallsDigest: String?
    let conversationId: UUID

    init(from message: ChatMessage) {
        self.role = message.role
        self.content = message.content
        self.isError = message.isError
        self.toolCallID = message.toolCallID
        self.conversationId = message.conversationId

        // 将 toolCalls 序列化为排序后的 JSON，确保确定性比较
        if let toolCalls = message.toolCalls, !toolCalls.isEmpty {
            if let data = try? JSONEncoder().encode(toolCalls),
               let json = String(data: data, encoding: .utf8) {
                self.toolCallsDigest = json
            } else {
                self.toolCallsDigest = nil
            }
        } else {
            self.toolCallsDigest = nil
        }
    }
}

// MARK: - Preview

#Preview("MessageDedup Overlay") {
    MessageDedupOverlay(content: Text("Content"))
        .inRootView()
}
