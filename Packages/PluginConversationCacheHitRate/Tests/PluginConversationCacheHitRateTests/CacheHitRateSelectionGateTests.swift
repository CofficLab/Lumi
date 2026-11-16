import Foundation
import ProviderMessage
import Testing
@testable import PluginConversationCacheHitRate

/// 「切换会话后工具栏仍显示上一会话统计」的回归测试（#599）。
///
/// 选择变化到新会话快照返回之间隔着 150ms debounce 与异步读盘。修复前 observer
/// 只更新 `selectedConversationID`，不清空 stats/history/unavailabilityReason，
/// 上一会话的命中率与详情在这段时间里被当作新会话的数据。修复经
/// `CacheHitRateSelectionGate` 门禁：选择一变就立即把展示态归零。
@Suite("缓存命中率选择清空门禁")
struct CacheHitRateSelectionGateTests {
    @Test("切到新会话时立即清空命中率统计")
    func selectionResetClearsStats() {
        let reset = CacheHitRateSelectionGate.reset(forConversationID: UUID())
        #expect(reset.stats == .empty)
        #expect(reset.stats.sampleCount == 0)
    }

    @Test("切到新会话时立即清空趋势历史")
    func selectionResetClearsHistory() {
        let reset = CacheHitRateSelectionGate.reset(forConversationID: UUID())
        #expect(reset.history.isEmpty)
    }

    @Test("切到新会话时显示等待态而非上一会话的不可用原因")
    func selectionResetShowsWaitingForNewConversation() {
        let reset = CacheHitRateSelectionGate.reset(forConversationID: UUID())
        #expect(reset.unavailabilityReason == .waitingForResponse)
    }

    @Test("切到无会话时显示未选择态")
    func selectionResetShowsNoSelectionForNil() {
        let reset = CacheHitRateSelectionGate.reset(forConversationID: nil)
        #expect(reset.unavailabilityReason == .noConversationSelected)
    }
}