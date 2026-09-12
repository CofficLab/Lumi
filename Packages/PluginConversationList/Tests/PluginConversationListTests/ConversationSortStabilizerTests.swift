import Foundation
import Testing
@testable import PluginConversationList

@Test @MainActor func sortTimeStaysAnchoredUntilTheHoldWindowExpires() {
    var now = Date(timeIntervalSince1970: 100)
    let stabilizer = ConversationSortStabilizer(holdWindowSeconds: 30, now: { now })
    let conversationID = UUID()

    #expect(stabilizer.effectiveSortTime(for: conversationID, lastMessageAt: now) == now)
    now.addTimeInterval(10)
    #expect(stabilizer.effectiveSortTime(for: conversationID, lastMessageAt: now) == Date(timeIntervalSince1970: 100))
    now.addTimeInterval(20)
    let refreshedTime = now.addingTimeInterval(5)
    #expect(stabilizer.effectiveSortTime(for: conversationID, lastMessageAt: refreshedTime) == refreshedTime)
}

@Test @MainActor func markingViewedAnchorsTheConversationAtTheCurrentTime() {
    var now = Date(timeIntervalSince1970: 500)
    let stabilizer = ConversationSortStabilizer(holdWindowSeconds: 30, now: { now })
    let conversationID = UUID()
    stabilizer.markViewed(conversationID: conversationID)

    #expect(stabilizer.effectiveSortTime(for: conversationID, lastMessageAt: Date(timeIntervalSince1970: 100)) == now)
    now.addTimeInterval(30)
    let newMessageTime = Date(timeIntervalSince1970: 600)
    #expect(stabilizer.effectiveSortTime(for: conversationID, lastMessageAt: newMessageTime) == newMessageTime)
}

@Test @MainActor func cleanupKeepsRecentAnchorsAndDropsOldOnes() {
    var now = Date(timeIntervalSince1970: 40)
    let stabilizer = ConversationSortStabilizer(holdWindowSeconds: 30, now: { now })
    let recentID = UUID()
    let oldID = UUID()
    _ = stabilizer.effectiveSortTime(for: recentID, lastMessageAt: Date(timeIntervalSince1970: 60))
    _ = stabilizer.effectiveSortTime(for: oldID, lastMessageAt: Date(timeIntervalSince1970: 39))

    now = Date(timeIntervalSince1970: 110)
    stabilizer.cleanup()
    now = Date(timeIntervalSince1970: 80)

    #expect(stabilizer.effectiveSortTime(for: recentID, lastMessageAt: Date(timeIntervalSince1970: 200)) == Date(timeIntervalSince1970: 60))
    #expect(stabilizer.effectiveSortTime(for: oldID, lastMessageAt: Date(timeIntervalSince1970: 200)) == Date(timeIntervalSince1970: 200))
}
