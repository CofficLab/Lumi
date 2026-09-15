import Foundation
import Testing
@testable import PluginConversationList

@Test func relativeTimeFormatsPastMinutesHoursAndDays() {
    #expect(Date(timeIntervalSinceNow: -5 * 60 - 1).relativeTime == "5 分钟前")
    #expect(Date(timeIntervalSinceNow: -2 * 60 * 60 - 1).relativeTime == "2 小时前")
    #expect(Date(timeIntervalSinceNow: -3 * 24 * 60 * 60 - 1).relativeTime == "3 天前")
}

@Test func relativeTimeTreatsRecentAndFutureDatesAsJustNow() {
    #expect(Date().relativeTime == "刚刚")
    #expect(Date(timeIntervalSinceNow: 1).relativeTime == "刚刚")
}

@Test func conversationPageCursorKeepsItsTimestampAndIdentifier() {
    let timestamp = Date(timeIntervalSince1970: 1234)
    let identifier = UUID()
    let cursor = ConversationPageCursor(lastMessageAt: timestamp, id: identifier)

    #expect(cursor.lastMessageAt == timestamp)
    #expect(cursor.id == identifier)
}
