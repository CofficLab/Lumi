import Foundation
import ProviderMessage
import Testing
@testable import PluginMessageListChatGPT

/// V5（ChatGPT）轮次投影缓存测试。
///
/// 基准是 V5 方案 Task 7 的性能要求：
/// - 历史 projection 只在历史 fingerprint 变化时 O(n) 重建；
/// - streaming/activity 只重建 live tail；
/// - 100 行历史 + 50 次流式快照，history rebuild 为 1。
@Suite("V5 轮次投影缓存")
@MainActor
struct ChatGPTTurnProjectionStoreTests {

    private func message(_ content: String, role: MessageRole = .user) -> Message {
        Message(conversationID: UUID(), role: role, content: content)
    }

    @Test("历史不变时流式快照不触发重建")
    func streamingDoesNotRebuildHistory() {
        let store = ChatGPTTurnProjectionStore()
        let history = (0..<100).map { message("第 \($0) 条") }

        _ = store.snapshot(history: history, streaming: nil, activity: nil)
        #expect(store.historyRebuildCount == 1)

        for _ in 0..<50 {
            let streaming = message("生成中", role: .assistant)
            _ = store.snapshot(history: history, streaming: streaming, activity: nil)
        }

        #expect(store.historyRebuildCount == 1)
    }

    @Test("历史内容变化触发重建")
    func historyChangeTriggersRebuild() {
        let store = ChatGPTTurnProjectionStore()
        let history = [message("第一段")]

        _ = store.snapshot(history: history, streaming: nil, activity: nil)
        #expect(store.historyRebuildCount == 1)

        _ = store.snapshot(history: [message("第二段")], streaming: nil, activity: nil)
        #expect(store.historyRebuildCount == 2)
    }

    @Test("等长正文替换触发重建并更新复制文本")
    func equalLengthReplacementTriggersRebuild() {
        let store = ChatGPTTurnProjectionStore()
        let conversationID = UUID()

        let first = Message(
            conversationID: conversationID,
            role: .assistant,
            content: "AAAA"
        )
        var projection = store.snapshot(history: [first], streaming: nil, activity: nil)
        #expect(projection.turns.first?.assistantCopyText == "AAAA")

        // 等长替换：长度不变，内容变了。
        let second = Message(
            conversationID: conversationID,
            role: .assistant,
            content: "BBBB"
        )
        projection = store.snapshot(history: [second], streaming: nil, activity: nil)

        #expect(store.historyRebuildCount == 2)
        #expect(projection.turns.first?.assistantCopyText == "BBBB")
    }

    @Test("流式尾行不改变历史轮次数量")
    func streamingDoesNotChangeHistoryTurnCount() {
        let store = ChatGPTTurnProjectionStore()
        let history = [
            message("问"),
            message("答", role: .assistant),
        ]

        let before = store.snapshot(history: history, streaming: nil, activity: nil)
        let streaming = message("生成中", role: .assistant)
        let after = store.snapshot(history: history, streaming: streaming, activity: nil)

        #expect(before.historyTurnCount == after.historyTurnCount)
        #expect(after.turns.count == after.historyTurnCount + 1)
    }

    @Test("reset 清空缓存")
    func resetClearsCache() {
        let store = ChatGPTTurnProjectionStore()
        let history = [message("问")]

        _ = store.snapshot(history: history, streaming: nil, activity: nil)
        #expect(store.historyRebuildCount == 1)

        store.reset()
        #expect(store.historyRebuildCount == 0)

        _ = store.snapshot(history: history, streaming: nil, activity: nil)
        #expect(store.historyRebuildCount == 1)
    }

    @Test("快照是确定性的")
    func snapshotIsDeterministic() {
        let store = ChatGPTTurnProjectionStore()
        let history = [message("问"), message("答", role: .assistant)]

        let first = store.snapshot(history: history, streaming: nil, activity: nil)
        let second = store.snapshot(history: history, streaming: nil, activity: nil)

        #expect(first.turns.map(\.id) == second.turns.map(\.id))
    }
}
