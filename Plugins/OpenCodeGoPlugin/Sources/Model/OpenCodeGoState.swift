import Foundation

/// OpenCode Go 配额状态
enum OpenCodeGoStatus: Sendable {
    case loading
    case success(OpenCodeGoState)
    case unavailable(String)
}

/// OpenCode Go 配额窗口（5小时滚动/每周/每月）
struct OpenCodeGoWindow: Sendable, Codable {
    let kind: String
    let label: String
    let pct: Double
    let used: Double
    let limit: Double
    let resetText: String?

    enum CodingKeys: String, CodingKey {
        case kind, label, pct, used, limit
        case resetText = "reset_text"
    }
}

/// OpenCode Go 服务端配额快照
struct OpenCodeGoServerQuota: Sendable, Codable {
    let kind: String
    let label: String
    let pct: Double
    let resetText: String?

    enum CodingKeys: String, CodingKey {
        case kind, label, pct
        case resetText = "reset_text"
    }
}

/// OpenCode Go API 状态响应
struct OpenCodeGoState: Sendable, Codable {
    let windows: [OpenCodeGoWindow]
    let rows: Int
    let key: Bool
    let server: [OpenCodeGoServerQuota]?
    let serverConfigured: Bool
    let ts: Int64

    enum CodingKeys: String, CodingKey {
        case windows, rows, key, server
        case serverConfigured = "server_configured"
        case ts
    }

    /// 获取 5 小时滚动窗口
    var sessionWindow: OpenCodeGoWindow? {
        windows.first { $0.kind == "session" }
    }

    /// 获取每周窗口
    var weeklyWindow: OpenCodeGoWindow? {
        windows.first { $0.kind == "weekly" }
    }

    /// 获取每月窗口
    var monthlyWindow: OpenCodeGoWindow? {
        windows.first { $0.kind == "monthly" }
    }

    /// 状态栏显示文本
    ///
    /// 格式: "5h: 81% · W: 98%"（5小时剩余% · 周剩余%）
    var statusBarText: String {
        var parts: [String] = []

        if let session = sessionWindow {
            let remaining = max(0, 100 - Int(session.pct))
            parts.append("5h: \(remaining)%")
        }

        if let weekly = weeklyWindow {
            let remaining = max(0, 100 - Int(weekly.pct))
            parts.append("W: \(remaining)%")
        }

        return parts.joined(separator: " · ")
    }

    /// 服务端配额状态栏文本（如果有官方数据）
    var serverStatusBarText: String? {
        guard let serverQuotas = server, !serverQuotas.isEmpty else { return nil }

        var parts: [String] = []
        for quota in serverQuotas {
            let remaining = max(0, 100 - Int(quota.pct))
            parts.append("\(quota.label): \(remaining)%")
        }

        return parts.joined(separator: " · ")
    }
}
