import Foundation
import Testing
@testable import PluginConversationList

/// 复现「后台会话被挤出有界摘要缓存后，回合完成不再生成未读提示」。
///
/// 旧实现每轮都用「缓存里的会话」与 `runningConversationIDs` 求交集，
/// 后台会话一旦被裁剪就从跟踪表里消失；回合真正结束时凑不出
/// running → 非 running 边缘，`markNeedsAttention` 永远不会被调用。
@Suite("回合结束检测")
struct ConversationAttentionScannerTests {

    @Test("被挤出缓存的会话完成时仍产生完成边缘（#993）")
    func evictedConversationStillReportsCompletion() {
        let evicted = UUID()

        let result = ConversationAttentionScanner.scan(
            cachedIDs: [],
            previouslyRunning: [evicted],
            isRunning: { _ in false }
        )

        #expect(
            result.finished == [evicted],
            "会话已不在缓存中，但回合结束的事实必须被识别出来，否则不会生成未读提示"
        )
        #expect(result.stillRunning.isEmpty)
    }

    @Test("被挤出缓存但仍在运行的会话必须继续被跟踪")
    func evictedRunningConversationStaysTracked() {
        let evicted = UUID()

        let result = ConversationAttentionScanner.scan(
            cachedIDs: [],
            previouslyRunning: [evicted],
            isRunning: { $0 == evicted }
        )

        #expect(result.stillRunning == [evicted])
        #expect(
            result.finished.isEmpty,
            "回合尚未结束，不得提前生成未读提示"
        )
    }

    @Test("从未观测为运行的会话结束时不得生成未读提示")
    func neverRunningConversationDoesNotFinish() {
        let cached = UUID()

        let result = ConversationAttentionScanner.scan(
            cachedIDs: [cached],
            previouslyRunning: [],
            isRunning: { _ in false }
        )

        #expect(result.finished.isEmpty)
        #expect(result.stillRunning.isEmpty)
    }

    @Test("缓存内的会话完成后停止跟踪")
    func cachedConversationFinishesOnce() {
        let cached = UUID()

        let result = ConversationAttentionScanner.scan(
            cachedIDs: [cached],
            previouslyRunning: [cached],
            isRunning: { _ in false }
        )

        #expect(result.finished == [cached])
        #expect(result.stillRunning.isEmpty)
    }
}
