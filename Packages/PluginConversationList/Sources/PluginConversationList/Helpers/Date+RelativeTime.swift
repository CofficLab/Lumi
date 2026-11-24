import Foundation

public extension Date {
    /// 返回相对于 `now` 的描述；`now` 由调用方注入，列表用周期性 tick 传入，
    /// 否则文本只在无关状态变化触发重绘时才会前进（#638）。
    /// - Returns: 如 "Just now", "5m ago", "2h ago", "3d ago"
    func relativeTime(now: Date) -> String {
        let delta = now.timeIntervalSince(self)
        guard delta >= 0 else { return "刚刚" }

        let minutes = Int(delta) / 60
        if minutes < 60 {
            return minutes < 1 ? "刚刚" : "\(minutes) 分钟前"
        }

        let hours = minutes / 60
        if hours < 24 {
            return "\(hours) 小时前"
        }

        let days = hours / 24
        return "\(days) 天前"
    }

    /// 返回相对于当前时间的描述
    /// - Returns: 如 "Just now", "5m ago", "2h ago", "3d ago"
    var relativeTime: String {
        relativeTime(now: Date())
    }
}
