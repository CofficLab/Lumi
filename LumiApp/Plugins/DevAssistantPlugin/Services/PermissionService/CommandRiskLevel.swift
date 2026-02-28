import SwiftUI

enum CommandRiskLevel: String, Codable, Sendable {
    case safe
    case low
    case medium
    case high

    var requiresPermission: Bool {
        switch self {
        case .safe:
            return false
        case .low:
            return false
        case .medium:
            return false
        case .high:
            return true
        }
    }

    var displayName: String {
        switch self {
        case .safe: return "安全"
        case .low: return "低风险"
        case .medium: return "中风险"
        case .high: return "高风险"
        }
    }

    var iconName: String {
        switch self {
        case .safe: return "checkmark.shield.fill"
        case .low: return "info.circle.fill"
        case .medium: return "exclamationmark.triangle.fill"
        case .high: return "exclamationmark.octagon.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .safe: return .green
        case .low: return .blue
        case .medium: return .orange
        case .high: return .red
        }
    }

    var reason: String? {
        switch self {
        case .safe:
            return nil
        case .low:
            return "此操作只读取信息，不会修改文件"
        case .medium:
            return "此操作可能修改文件或访问网络"
        case .high:
            return "此操作可能造成数据丢失或系统更改"
        }
    }
}
