import Foundation

/// 智谱配额数据
struct ZhipuQuotaData {
    let level: String
    let usedPercent: Int
    let leftPercent: Int
    let nextResetTime: TimeInterval

    // MCP 每月额度相关
    let mcpLeftPercent: Int
    let mcpNextResetTime: TimeInterval

    /// 等级显示文本
    var levelDisplay: String {
        "GLM \(level.isEmpty ? "Lite" : level)"
    }

    /// 重置时间文本（完整日期时间格式）
    var resetTime: String {
        let date = Date(timeIntervalSince1970: nextResetTime / 1000.0)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }

    /// 重置时间文本（相对时间格式，如"2 小时后"）
    var resetTimeRelative: String {
        let date = Date(timeIntervalSince1970: nextResetTime / 1000.0)
        let now = Date()
        let interval = date.timeIntervalSince(now)

        if interval < 0 {
            return "即将重置"
        } else if interval < 3600 {
            return "约 \(Int(interval / 60)) 分钟后"
        } else if interval < 86400 {
            return "约 \(Int(interval / 3600)) 小时后"
        } else {
            return "\(Int(interval / 86400)) 天后"
        }
    }

    /// MCP 额度重置时间文本
    var mcpResetTime: String {
        let date = Date(timeIntervalSince1970: mcpNextResetTime / 1000.0)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }

    /// MCP 额度重置相对时间
    var mcpResetTimeRelative: String {
        let date = Date(timeIntervalSince1970: mcpNextResetTime / 1000.0)
        let now = Date()
        let interval = date.timeIntervalSince(now)

        if interval < 0 {
            return "即将重置"
        } else if interval < 3600 {
            return "约 \(Int(interval / 60)) 分钟后"
        } else if interval < 86400 {
            return "约 \(Int(interval / 3600)) 小时后"
        } else if interval < 2592000 {
            return "\(Int(interval / 86400)) 天后"
        } else {
            return "\(Int(interval / 2592000)) 个月后"
        }
    }

    /// 状态栏显示文本
    var statusText: String {
        "\(levelDisplay) | 剩余 \(leftPercent)% | 重置 \(resetTime)"
    }
}