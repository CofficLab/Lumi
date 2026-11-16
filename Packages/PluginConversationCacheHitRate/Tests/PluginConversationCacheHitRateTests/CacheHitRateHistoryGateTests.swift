import Foundation
import ProviderMessage
import Testing
@testable import PluginConversationCacheHitRate

/// 「弹窗关闭时仍重建整段缓存命中率历史」的回归测试（#1226）。
///
/// 工具栏数值常驻可见，但趋势历史只在弹窗里展示。`CacheHitRateHistory.build`
/// 会对整段消息排序并逐条累计（O(M log M)），此前每次刷新都无条件执行，
/// 长会话里每条消息插入都在主线程重排历史，造成卡顿。
///
/// 修复：历史构建经 `CacheHitRateHistoryGate` 门禁——关闭时返回空历史，
/// 打开时用最近快照即时补建。工具栏数值（stats）不受门禁影响，始终即时刷新。
@Suite("缓存命中率历史构建门禁")
struct CacheHitRateHistoryGateTests {
    private let conversationID = UUID()

    private var snapshot: [Message] {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        return [
            Message(
                conversationID: conversationID,
                role: .assistant,
                content: "a",
                createdAt: base,
                cachedInputTokenCount: 0,
                cacheTotalInputTokenCount: 8_000
            ),
            Message(
                conversationID: conversationID,
                role: .assistant,
                content: "b",
                createdAt: base.addingTimeInterval(600),
                cachedInputTokenCount: 5_200,
                cacheTotalInputTokenCount: 11_000
            ),
        ]
    }

    @Test func closedPopoverSkipsHistoryBuild() {
        let messages = snapshot
        let history = CacheHitRateHistoryGate.resolve(isPopoverPresented: false, snapshot: messages)
        #expect(history.isEmpty, "弹窗关闭时不应构建趋势历史")
    }

    @Test func openPopoverBuildsHistoryFromSnapshot() {
        let messages = snapshot
        let history = CacheHitRateHistoryGate.resolve(isPopoverPresented: true, snapshot: messages)
        #expect(history == CacheHitRateHistory.build(from: messages))
        #expect(history.samples.count == 2)
    }

    @Test func openPopoverWithEmptySnapshotIsEmpty() {
        let history = CacheHitRateHistoryGate.resolve(isPopoverPresented: true, snapshot: [])
        #expect(history.isEmpty)
    }
}