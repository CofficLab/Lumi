import Foundation

public extension Date {
    /// 返回相对于当前时间的描述
    /// - Returns: 如 "Just now", "5m ago", "2h ago", "3d ago"
    var relativeTime: String {
        let delta = Date().timeIntervalSince(self)
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
}
