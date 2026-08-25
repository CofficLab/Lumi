import Foundation

/// 命令风险等级（纯逻辑部分，UI 扩展在 LumiUI）
///
/// 用于评估工具调用的风险级别，决定是否需要用户授权。
/// `iconName` 和 `iconColor` 等 UI 属性在 `LumiUI` 的 extension 中定义。
public enum CommandRiskLevel: String, Codable, Sendable {
    case safe
    case low
    case medium
    case high

    /// 是否需要用户授权
    public var requiresPermission: Bool {
        switch self {
        case .safe: return false
        case .low: return false
        case .medium: return false
        case .high: return true
        }
    }

    /// 显示名称
    public var displayName: String {
        switch self {
        case .safe: return "安全"
        case .low: return "低风险"
        case .medium: return "中风险"
        case .high: return "高风险"
        }
    }

    /// 风险原因说明
    public var reason: String? {
        switch self {
        case .safe: return nil
        case .low: return "此操作只读取信息，不会修改文件"
        case .medium: return "此操作可能修改文件或访问网络"
        case .high: return "此操作可能造成数据丢失或系统更改"
        }
    }
}
