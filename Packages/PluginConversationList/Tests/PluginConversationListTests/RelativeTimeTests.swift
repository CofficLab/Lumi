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

/// #638：注入的 now 必须真正驱动间隔计算，列表的周期 tick 才能让
/// 相对时间在空闲时前进。
@Test func relativeTimeIsDrivenByTheInjectedNow() {
    let base = Date(timeIntervalSince1970: 1_000_000)
    #expect(base.relativeTime(now: base) == "刚刚")
    #expect(base.relativeTime(now: base.addingTimeInterval(5 * 60 + 1)) == "5 分钟前")
    #expect(base.relativeTime(now: base.addingTimeInterval(2 * 60 * 60 + 1)) == "2 小时前")
    #expect(base.relativeTime(now: base.addingTimeInterval(3 * 24 * 60 * 60 + 1)) == "3 天前")
    // 未来时间同样按注入的 now 判定为「刚刚」。
    #expect(base.relativeTime(now: base.addingTimeInterval(-1)) == "刚刚")
}

@Test func conversationPageCursorKeepsItsTimestampAndIdentifier() {
    let timestamp = Date(timeIntervalSince1970: 1234)
    let identifier = UUID()
    let cursor = ConversationPageCursor(lastMessageAt: timestamp, id: identifier)

    #expect(cursor.lastMessageAt == timestamp)
    #expect(cursor.id == identifier)
}
