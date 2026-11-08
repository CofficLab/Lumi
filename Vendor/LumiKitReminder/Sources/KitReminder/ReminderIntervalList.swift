import Foundation

/// 间隔列表的去重工具。
///
/// 提醒插件的间隔用「分钟 / 小时」两种 case 表达，同一时长可能有两种写法
/// （如 `.minutes(60)` 与 `.hours(1)`）。若按 case 去重，选择器会渲染出两个
/// 按钮，且因为高亮判定是 `selectedInterval == option.timeInterval`
/// （按秒比较），两个按钮会**同时高亮**——用户看到的是同一个时长的两个入口。
///
/// 这里统一以**时长（秒）**作为去重键，与选择器的高亮判定保持一致。
public enum ReminderIntervalList {
    /// 按时长去重，并按时长升序排列。
    ///
    /// 每个时长只保留**最先出现**的项，因此把内置预设放在前面传入时，
    /// 预设会优先于自定义项（例如自定义 60 分钟不会与预设 1 小时并存）。
    ///
    /// - Parameters:
    ///   - options: 待处理选项，建议按「预设 + 自定义」的顺序传入。
    ///   - timeInterval: 从选项取出时长（秒）的闭包。
    /// - Returns: 去重后按时长升序排列的选项。
    public static func deduped<T>(
        _ options: [T],
        timeInterval: (T) -> TimeInterval
    ) -> [T] {
        var seen = Set<TimeInterval>()
        var result: [T] = []

        for option in options {
            let seconds = timeInterval(option)
            if seen.insert(seconds).inserted {
                result.append(option)
            }
        }

        return result.sorted { timeInterval($0) < timeInterval($1) }
    }
}
