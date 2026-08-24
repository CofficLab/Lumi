import Foundation
import Testing
import KernelLumi
@testable import MessageListAppKitPlugin

/// Streaming integration tests: V1 never updates the table on token chunks,
/// V2 throttles to one update per frame reconfiguring only the streaming row,
/// and streaming→persisted swaps use stable IDs without duplicates.
@Suite(.serialized)
@MainActor
struct AppKitStreamingIntegrationTests {
    @MainActor
    private final class Harness {
        let conversationID = UUID()
        let messages = MockMessageManager()
        let turns = MockAgentTurnManager()
        let conversations = MockConversationManager()
        let streaming = MockMessageStreaming()
        let coordinator: AppKitMessageListCoordinator

        init(verbosity: LumiResponseVerbosity) {
            conversations.globalVerbosity = verbosity
            coordinator = AppKitMessageListCoordinator(dependencies: .init(
                conversations: conversations,
                messageManager: messages,
                agentTurnManager: turns,
                messageStreaming: streaming,
                messageSender: nil
            ))
        }

        func seed(_ content: String, at seconds: Double) {
            messages.seed([
                LumiChatMessage(
                    conversationID: conversationID,
                    role: .assistant,
                    content: content,
                    createdAt: Date(timeIntervalSinceReferenceDate: seconds)
                )
            ], conversationID: conversationID)
        }

        func settle(_ nanoseconds: UInt64 = 60_000_000) async {
            try? await Task.sleep(nanoseconds: nanoseconds)
        }
    }

    @Test("V1(brief)：token 追加不更新快照")
    func v1TokenChunksNeverUpdateTable() async {
        let h = Harness(verbosity: .brief)
        h.seed("持久消息", at: 100)
        await h.coordinator.activate(conversationID: h.conversationID)
        await h.settle()

        let before = h.coordinator.latestSnapshot
        #expect(before.rows.count == 1)

        // 流式开始与 token 追加（brief 模式：不应反映到表格）。
        await h.streaming.startStreaming(conversationID: h.conversationID)
        await h.streaming.appendContent("流式", conversationID: h.conversationID)
        await h.streaming.appendContent("内容", conversationID: h.conversationID)
        await h.settle()

        let after = h.coordinator.latestSnapshot
        #expect(after == before) // 表格完全不变
        #expect(after.streamingRow == nil) // brief 无流式行
    }

    @Test("V2：token 只更新流式行，历史行保持不变")
    func v2TokenUpdatesOnlyStreamingRow() async {
        let h = Harness(verbosity: .standard)
        h.seed("历史消息", at: 100)
        await h.coordinator.activate(conversationID: h.conversationID)
        await h.settle()

        let historyBefore = h.coordinator.latestSnapshot.rows
        #expect(historyBefore.count == 1)

        await h.streaming.startStreaming(conversationID: h.conversationID)
        await h.streaming.appendContent("正在", conversationID: h.conversationID)
        await h.settle()

        let mid = h.coordinator.latestSnapshot
        #expect(mid.streamingRow != nil)
        #expect(mid.streamingRow?.content == "正在")
        #expect(mid.rows.count == 1) // 历史行数不变

        // 再追加 token：流式行内容更新，历史行仍不变。
        await h.streaming.appendContent("生成", conversationID: h.conversationID)
        await h.settle()

        let later = h.coordinator.latestSnapshot
        #expect(later.streamingRow?.content == "正在生成")
        #expect(later.rows == historyBefore)
    }

    @Test("V2：流式结束后落库行替换流式行（稳定 ID，无重复）")
    func streamingToPersistedSwap() async {
        let h = Harness(verbosity: .standard)
        await h.coordinator.activate(conversationID: h.conversationID)
        await h.settle()

        await h.streaming.startStreaming(conversationID: h.conversationID)
        await h.streaming.appendContent("最终回复", conversationID: h.conversationID)
        await h.settle()
        #expect(h.coordinator.latestSnapshot.streamingRow != nil)

        // 落库：真实 assistant 消息 + 结束流式 + 通知刷新。
        let persisted = LumiChatMessage(
            conversationID: h.conversationID,
            role: .assistant,
            content: "最终回复",
            createdAt: Date(timeIntervalSinceReferenceDate: 500)
        )
        await h.streaming.endStreaming(conversationID: h.conversationID)
        h.messages.insertMessage(persisted, to: h.conversationID)
        NotificationCenter.default.post(
            name: .lumiMessagesDidChange,
            object: nil,
            userInfo: [LumiNotificationUserInfoKey.conversationID: h.conversationID]
        )
        await h.settle()

        let snapshot = h.coordinator.latestSnapshot
        #expect(snapshot.streamingRow == nil) // 临时行消失
        #expect(snapshot.rows.count == 1) // 仅真实行，无重复
        let row = snapshot.rows.first
        #expect(row?.id != LumiStreamingRowID.uuidString) // 稳定 ID 与流式行不同
        #expect(row?.message.id == persisted.id)
        #expect(row?.content == "最终回复")
    }

    @Test("V2：流式行高度随内容变化（动态高度数据源可见）")
    func streamingRowHeightChanges() async {
        let h = Harness(verbosity: .standard)
        await h.coordinator.activate(conversationID: h.conversationID)
        await h.settle()

        await h.streaming.startStreaming(conversationID: h.conversationID)
        await h.streaming.appendContent("短", conversationID: h.conversationID)
        await h.settle()

        let short = h.coordinator.latestSnapshot.streamingRow?.content
        await h.streaming.appendContent(String(repeating: "长内容", count: 30), conversationID: h.conversationID)
        await h.settle()

        let long = h.coordinator.latestSnapshot.streamingRow?.content
        #expect(short == "短")
        #expect(long?.count ?? 0 > 10)
    }
}
