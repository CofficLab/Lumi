import Foundation
import Testing
@testable import PluginConversationCacheHitRate

@Suite("缓存命中率刷新门禁")
struct CacheHitRateRefreshGateTests {
    private let conversationID = UUID()

    @Test func latestRevisionForCurrentConversationIsPublished() {
        #expect(
            CacheHitRateRefreshGate.shouldPublish(
                revision: 3,
                currentRevision: 3,
                conversationID: conversationID,
                selectedConversationID: conversationID,
                isCancelled: false
            )
        )
    }

    @Test func supersededRevisionIsDropped() {
        // 场景：#998 中 S1（revision 1）晚于 S2（revision 2）返回，不能覆盖新统计。
        #expect(
            !CacheHitRateRefreshGate.shouldPublish(
                revision: 1,
                currentRevision: 2,
                conversationID: conversationID,
                selectedConversationID: conversationID,
                isCancelled: false
            )
        )
    }

    @Test func cancelledRefreshIsDropped() {
        #expect(
            !CacheHitRateRefreshGate.shouldPublish(
                revision: 1,
                currentRevision: 1,
                conversationID: conversationID,
                selectedConversationID: conversationID,
                isCancelled: true
            )
        )
    }

    @Test func staleConversationSnapshotIsDropped() {
        #expect(
            !CacheHitRateRefreshGate.shouldPublish(
                revision: 1,
                currentRevision: 1,
                conversationID: UUID(),
                selectedConversationID: conversationID,
                isCancelled: false
            )
        )
    }
}
