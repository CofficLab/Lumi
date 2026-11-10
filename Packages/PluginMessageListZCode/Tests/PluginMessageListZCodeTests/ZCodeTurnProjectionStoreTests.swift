import Foundation
import ProviderMessage
import Testing
@testable import PluginMessageListZCode

/// `ZCodeTurnProjectionStore` 的增量 tail 契约测试。
///
/// 关键不变式：历史轮次只在 `historyRows` 变化时做一次 O(n) 重建；
/// 流式 / 活动行更新只重做 live tail，不得每个 token 扫描整个长会话。
@Suite("ZCode 轮次投影缓存")
@MainActor
struct ZCodeTurnProjectionStoreTests {

    @Test("首次读取会构建历史投影")
    func firstReadBuildsHistoryProjection() {
        let store = ZCodeTurnProjectionStore()
        let history = [makeMessage(role: .user, content: "问题")]

        let snapshot = store.snapshot(history: history, streaming: nil, activity: nil)

        #expect(snapshot.turns.count == 1)
        #expect(store.historyRebuildCount == 1)
    }

    @Test("历史未变化时重复读取不重建历史")
    func unchangedHistoryDoesNotRebuild() {
        let store = ZCodeTurnProjectionStore()
        let history = [makeMessage(role: .user, content: "问题")]

        _ = store.snapshot(history: history, streaming: nil, activity: nil)
        _ = store.snapshot(history: history, streaming: nil, activity: nil)
        _ = store.snapshot(history: history, streaming: nil, activity: nil)

        #expect(store.historyRebuildCount == 1)
    }

    @Test("历史变化时才重建历史")
    func changedHistoryRebuilds() {
        let store = ZCodeTurnProjectionStore()
        let history = [makeMessage(role: .user, content: "问题")]

        _ = store.snapshot(history: history, streaming: nil, activity: nil)
        let appended = history + [makeMessage(role: .assistant, content: "回答")]
        _ = store.snapshot(history: appended, streaming: nil, activity: nil)

        #expect(store.historyRebuildCount == 2)
    }

    @Test("100 次流式更新只触发一次历史 O(n) 重建")
    func hundredStreamingUpdatesRebuildHistoryOnlyOnce() {
        let store = ZCodeTurnProjectionStore()
        let history = (0..<40).map { index in
            makeMessage(role: .user, content: "问题 \(index)")
        }

        _ = store.snapshot(history: history, streaming: nil, activity: nil)
        let rebuildsAfterHistory = store.historyRebuildCount

        for tick in 0..<100 {
            let streaming = makeMessage(role: .assistant, content: "流式 \(tick)")
            _ = store.snapshot(history: history, streaming: streaming, activity: nil)
        }

        #expect(rebuildsAfterHistory == 1)
        #expect(store.historyRebuildCount == 1)
    }

    @Test("流式更新只改变 live tail，不改变历史轮次身份")
    func streamingUpdateOnlyChangesLiveTail() {
        let store = ZCodeTurnProjectionStore()
        let history = [
            makeMessage(role: .user, content: "问题"),
            makeMessage(role: .assistant, content: "回答"),
        ]

        let before = store.snapshot(history: history, streaming: nil, activity: nil)
        let after = store.snapshot(
            history: history,
            streaming: makeMessage(role: .assistant, content: "流式"),
            activity: nil
        )

        #expect(after.historyTurnIDs == before.historyTurnIDs)
        #expect(after.historyTurnCount == before.historyTurnCount)
        #expect(after.turns.count == before.turns.count + 1)
    }

    @Test("流式行消失后回到纯历史快照")
    func streamingDisappearingReturnsToHistorySnapshot() {
        let store = ZCodeTurnProjectionStore()
        let history = [makeMessage(role: .user, content: "问题")]

        _ = store.snapshot(history: history, streaming: nil, activity: nil)
        _ = store.snapshot(
            history: history,
            streaming: makeMessage(role: .assistant, content: "流式"),
            activity: nil
        )
        let final = store.snapshot(history: history, streaming: nil, activity: nil)

        #expect(final.turns.count == 1)
        #expect(final.turns[0].rows[0].origin == .history)
    }

    @Test("历史重置（切换会话）后重新构建")
    func historyResetTriggersRebuild() {
        let store = ZCodeTurnProjectionStore()

        _ = store.snapshot(history: [makeMessage(role: .user, content: "A")], streaming: nil, activity: nil)
        store.reset()
        _ = store.snapshot(history: [makeMessage(role: .user, content: "B")], streaming: nil, activity: nil)

        #expect(store.historyRebuildCount == 2)
    }

    @Test("空历史与空流式不崩溃")
    func emptyInputsDoNotCrash() {
        let store = ZCodeTurnProjectionStore()

        let snapshot = store.snapshot(history: [], streaming: nil, activity: nil)

        #expect(snapshot.turns.isEmpty)
        #expect(store.historyRebuildCount == 1)
    }

    @Test("活动行存在时也能稳定快照")
    func activityRowProducesStableSnapshot() {
        let store = ZCodeTurnProjectionStore()
        let history = [makeMessage(role: .user, content: "问题")]
        let activity = makeMessage(role: .assistant, content: "活动")

        let first = store.snapshot(history: history, streaming: nil, activity: activity)
        let second = store.snapshot(history: history, streaming: nil, activity: activity)

        #expect(first == second)
        #expect(first.turns.count == 2)
        #expect(store.historyRebuildCount == 1)
    }

    // MARK: - 辅助

    private func makeMessage(
        role: MessageRole,
        content: String,
        turnID: UUID? = nil
    ) -> Message {
        Message(
            conversationID: UUID(),
            role: role,
            content: content,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            turnID: turnID
        )
    }
}
