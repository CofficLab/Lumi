import Foundation
import Testing
@testable import PluginMessageRenderer

/// V4（ZCode）轮尾时间标签契约测试。
///
/// 基准是 ZCode 3.15.1 的 `packages/ui/src/v4/messageTimeLabel.ts`：
/// - 今天：本地 locale 的 `HH:mm`；
/// - 昨天：本地化「昨天 HH:mm」；
/// - 今年其他日期：`月、日、HH:mm`；
/// - 非今年：`年、月、日、HH:mm`；
/// - 无效 / 非正时间戳：不显示。
///
/// - Important: 测试必须注入固定的 `now`、`Calendar`、locale 与 time zone，
///   不能依赖运行机器的当前日期。
@Suite("ZCode 轮尾时间标签")
struct ZCodeMessageTimeLabelTests {

    // MARK: - 固定环境

    /// 固定「现在」：2026-06-15 12:00:00（UTC）。
    private static let now = Date(timeIntervalSince1970: 1_781_524_800)
    /// 固定日历：UTC 时区，便于断言。
    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }
    /// 固定 locale。
    private static let locale = Locale(identifier: "en_US_POSIX")

    // MARK: - 无效输入

    @Test("非正时间戳不显示")
    func nonPositiveTimestampIsHidden() {
        #expect(ZCodeMessageTimeLabel.format(timestamp: 0, now: Self.now, calendar: Self.calendar, locale: Self.locale) == nil)
        #expect(ZCodeMessageTimeLabel.format(timestamp: -1, now: Self.now, calendar: Self.calendar, locale: Self.locale) == nil)
    }

    @Test("非有限时间戳不显示")
    func nonFiniteTimestampIsHidden() {
        #expect(ZCodeMessageTimeLabel.format(timestamp: .nan, now: Self.now, calendar: Self.calendar, locale: Self.locale) == nil)
        #expect(ZCodeMessageTimeLabel.format(timestamp: .infinity, now: Self.now, calendar: Self.calendar, locale: Self.locale) == nil)
    }

    @Test("无效的 now 不显示")
    func invalidNowIsHidden() {
        let timestamp = Self.now.timeIntervalSince1970
        #expect(ZCodeMessageTimeLabel.format(timestamp: timestamp, now: Date(timeIntervalSince1970: .nan), calendar: Self.calendar, locale: Self.locale) == nil)
    }

    // MARK: - 今天

    @Test("今天显示本地 HH:mm")
    func todayShowsTimeOnly() {
        // 今天 09:05（UTC）。
        let timestamp = Self.calendar.date(bySettingHour: 9, minute: 5, second: 0, of: Self.now)!.timeIntervalSince1970

        let label = ZCodeMessageTimeLabel.format(
            timestamp: timestamp,
            now: Self.now,
            calendar: Self.calendar,
            locale: Self.locale
        )

        #expect(label == "09:05")
    }

    // MARK: - 昨天

    @Test("昨天显示昨天前缀加 HH:mm")
    func yesterdayShowsLocalizedPrefix() {
        let yesterday = Self.calendar.date(byAdding: .day, value: -1, to: Self.now)!
        let timestamp = Self.calendar.date(bySettingHour: 9, minute: 5, second: 0, of: yesterday)!.timeIntervalSince1970

        let label = ZCodeMessageTimeLabel.format(
            timestamp: timestamp,
            now: Self.now,
            calendar: Self.calendar,
            locale: Self.locale
        )

        #expect(label == "Yesterday 09:05")
    }

    // MARK: - 今年

    @Test("今年其他日期显示月日加 HH:mm")
    func sameYearShowsMonthDayAndTime() {
        let earlier = Self.calendar.date(byAdding: .day, value: -10, to: Self.now)!
        let timestamp = Self.calendar.date(bySettingHour: 14, minute: 30, second: 0, of: earlier)!.timeIntervalSince1970

        let label = ZCodeMessageTimeLabel.format(
            timestamp: timestamp,
            now: Self.now,
            calendar: Self.calendar,
            locale: Self.locale
        )

        // 2026-06-05 14:30 → "6/5, 14:30"
        #expect(label == "6/5, 14:30")
    }

    // MARK: - 跨年

    @Test("非今年显示年月日加 HH:mm")
    func differentYearShowsFullDate() {
        let lastYear = Self.calendar.date(byAdding: .year, value: -1, to: Self.now)!
        let timestamp = Self.calendar.date(bySettingHour: 8, minute: 15, second: 0, of: lastYear)!.timeIntervalSince1970

        let label = ZCodeMessageTimeLabel.format(
            timestamp: timestamp,
            now: Self.now,
            calendar: Self.calendar,
            locale: Self.locale
        )

        // 2025-06-15 08:15 → "2025/6/15, 08:15"
        #expect(label == "2025/6/15, 08:15")
    }

    // MARK: - 确定性

    @Test("同一输入总是得到同一结果")
    func formattingIsDeterministic() {
        let timestamp = Self.now.timeIntervalSince1970 - 3_600

        let first = ZCodeMessageTimeLabel.format(
            timestamp: timestamp,
            now: Self.now,
            calendar: Self.calendar,
            locale: Self.locale
        )
        let second = ZCodeMessageTimeLabel.format(
            timestamp: timestamp,
            now: Self.now,
            calendar: Self.calendar,
            locale: Self.locale
        )

        #expect(first == second)
    }

    @Test("昨天前缀可本地化")
    func yesterdayPrefixIsLocalizable() {
        let yesterday = Self.calendar.date(byAdding: .day, value: -1, to: Self.now)!
        let timestamp = Self.calendar.date(bySettingHour: 9, minute: 5, second: 0, of: yesterday)!.timeIntervalSince1970

        let label = ZCodeMessageTimeLabel.format(
            timestamp: timestamp,
            now: Self.now,
            calendar: Self.calendar,
            locale: Self.locale,
            yesterdayPrefix: "昨天"
        )

        #expect(label == "昨天 09:05")
    }
}
