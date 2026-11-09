import Foundation

/// V4（ZCode）轮尾操作栏的时间标签。
///
/// 基准是 ZCode 3.15.1 的 `packages/ui/src/v4/messageTimeLabel.ts`：
///
/// | 条件 | 显示 |
/// |---|---|
/// | 无效 / 非正时间戳 | 不显示 |
/// | 今天 | 本地 locale 的 HH:mm |
/// | 昨天 | 本化「昨天 HH:mm」 |
/// | 今年其他日期 | 月、日、HH:mm |
/// | 非今年 | 年、月、日、HH:mm |
///
/// - Important: `now`、`Calendar`、`locale` 全部**注入**，
///   因此测试不依赖运行机器的当前日期。
enum ZCodeMessageTimeLabel {

    /// 生成时间标签。
    ///
    /// - Parameters:
    ///   - timestamp: Unix 时间戳（秒）。
    ///   - now: 参照的「现在」。
    ///   - calendar: 日历（含时区）。
    ///   - locale: 本地化 locale。
    ///   - yesterdayPrefix: 「昨天」的本地化前缀。
    /// - Returns: 标签文本；无效输入返回 nil（不显示）。
    static func format(
        timestamp: TimeInterval,
        now: Date,
        calendar: Calendar,
        locale: Locale,
        yesterdayPrefix: String = "Yesterday"
    ) -> String? {
        guard timestamp.isFinite, timestamp > 0 else { return nil }
        guard now.timeIntervalSince1970.isFinite else { return nil }

        let messageDate = Date(timeIntervalSince1970: timestamp)
        let timeText = timeFormatter(locale: locale, timeZone: calendar.timeZone).string(from: messageDate)

        // 今天：只显示时间。
        if calendar.isDate(messageDate, inSameDayAs: now) {
            return timeText
        }

        // 昨天：本地化的「昨天 + 时间」。
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(messageDate, inSameDayAs: yesterday) {
            return "\(yesterdayPrefix) \(timeText)"
        }

        // 今年其他日期：月、日、时间。
        if calendar.component(.year, from: messageDate) == calendar.component(.year, from: now) {
            return monthDayTimeFormatter(locale: locale, timeZone: calendar.timeZone)
                .string(from: messageDate)
        }

        // 非今年：年、月、日、时间。
        return yearMonthDayTimeFormatter(locale: locale, timeZone: calendar.timeZone)
            .string(from: messageDate)
    }

    // MARK: - 私有

    /// `HH:mm`。
    private static func timeFormatter(locale: Locale, timeZone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateFormat = "HH:mm"
        return formatter
    }

    /// `月、日 HH:mm`。
    private static func monthDayTimeFormatter(locale: Locale, timeZone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateFormat = "M/d, HH:mm"
        return formatter
    }

    /// `年、月、日 HH:mm`。
    private static func yearMonthDayTimeFormatter(locale: Locale, timeZone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy/M/d, HH:mm"
        return formatter
    }
}
