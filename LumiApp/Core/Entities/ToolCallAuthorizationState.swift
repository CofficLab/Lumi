import Foundation

/// 单条工具调用的授权结果（存于 `ToolCall.authorizationState`，随 `toolCalls` 序列化）。
enum ToolCallAuthorizationState: String, Codable, Sendable, Equatable, CaseIterable {
    /// 判定为无风险，可直接执行
    case noRisk
    /// 由策略自动批准（如标题栏「自动批准」）
    case autoApproved
    /// 用户明确同意
    case userApproved
    /// 用户明确拒绝
    case userRejected
    /// 尚未授权，等待用户或策略处理
    case pendingAuthorization

    /// 简短中文标签（用于 UI）
    var displayName: String {
        switch self {
        case .noRisk: return "无风险"
        case .autoApproved: return "自动同意"
        case .userApproved: return "用户同意"
        case .userRejected: return "用户拒绝"
        case .pendingAuthorization: return "等待授权"
        }
    }

    /// 是否仍等待用户或策略处理（未同意也未拒绝）
    var needsAuthorizationPrompt: Bool {
        self == .pendingAuthorization
    }
}
