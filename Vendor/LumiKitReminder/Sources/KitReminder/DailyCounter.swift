import Foundation

/// 「今日次数」计数器。
///
/// 记录某一类休息提醒当天已触发的次数，并把计数与**所属日期**一起持久化：
/// - 读取时若发现计数属于昨天，今天的计数就是 0；
/// - 跨零点后无需任何清理动作，下一次读取即自然归零；
/// - 重启 App 后计数仍在。
///
/// 状态落在插件专属目录的 `settings.plist`（见 `ReminderStateStore`），
/// 遵循 CofficLab 兄弟项目的存储规范，不使用 `UserDefaults`。
public final class DailyCounter: @unchecked Sendable {
    /// 状态键：计数所属日期（以「天」为单位的时间戳）。
    public static let dayKeySuffix = ".countDay"
    /// 状态键：当日计数。
    public static let countKeySuffix = ".count"

    private let store: ReminderStateStore
    private let keyPrefix: String
    private let calendar: Calendar
    private let dayProvider: @Sendable () -> Date

    /// - Parameters:
    ///   - store: 插件状态存储。
    ///   - keyPrefix: 计数键前缀（不同提醒类型使用不同前缀）。
    ///   - calendar: 用于判定「今天」的日历（默认当前日历）。
    ///   - dayProvider: 提供当前日期的闭包，测试可注入固定时间。
    public init(
        store: ReminderStateStore,
        keyPrefix: String,
        calendar: Calendar = .current,
        dayProvider: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.store = store
        self.keyPrefix = keyPrefix
        self.calendar = calendar
        self.dayProvider = dayProvider
    }

    /// 今天的计数；若已存储的计数属于往前的日期则返回 0。
    public var todayCount: Int {
        guard let storedDay = store.integer(forKey: Self.dayKey(for: keyPrefix)),
              let count = store.integer(forKey: Self.countKey(for: keyPrefix)),
              storedDay == currentDayIdentifier
        else {
            return 0
        }
        return count
    }

    /// 计数加一。
    public func increment() {
        let today = currentDayIdentifier
        let next: Int
        if store.integer(forKey: Self.dayKey(for: keyPrefix)) == today,
           let existing = store.integer(forKey: Self.countKey(for: keyPrefix)) {
            next = existing + 1
        } else {
            // 新的一天，从 1 开始计数
            next = 1
        }
        store.setInteger(today, forKey: Self.dayKey(for: keyPrefix))
        store.setInteger(next, forKey: Self.countKey(for: keyPrefix))
    }

    /// 把计数重置为 0（仍归属今天）。
    public func reset() {
        store.setInteger(currentDayIdentifier, forKey: Self.dayKey(for: keyPrefix))
        store.setInteger(0, forKey: Self.countKey(for: keyPrefix))
    }

    /// 当前日期的「天」标识：按日历取年月日，转成当天起始时刻的时间戳。
    private var currentDayIdentifier: Int {
        let now = dayProvider()
        let start = calendar.startOfDay(for: now)
        return Int(start.timeIntervalSince1970)
    }

    private static func dayKey(for prefix: String) -> String {
        prefix + dayKeySuffix
    }

    private static func countKey(for prefix: String) -> String {
        prefix + countKeySuffix
    }
}
