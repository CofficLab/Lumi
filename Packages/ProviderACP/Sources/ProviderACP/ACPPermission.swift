import Foundation

// MARK: - session/request_permission

/// `session/request_permission` 请求参数（Agent → Client）。
/// 参考：https://agentclientprotocol.com/protocol/tool-calls
public struct ACPRequestPermissionParams: Sendable, Equatable, Codable {
    /// 会话 ID。
    public var sessionId: ACPSessionId
    /// 待授权的工具调用详情。
    public var toolCall: ToolCallUpdate
    /// 提供给用户的权限选项列表。
    public var options: [ACPPermissionOption]

    public init(sessionId: ACPSessionId, toolCall: ToolCallUpdate, options: [ACPPermissionOption]) {
        self.sessionId = sessionId
        self.toolCall = toolCall
        self.options = options
    }
}

/// 权限选项。
public struct ACPPermissionOption: Sendable, Equatable, Codable {
    /// 选项唯一 ID。
    public var optionId: String
    /// 展示标签。
    public var name: String
    /// 选项类别（帮助 Client 选择图标与 UI 处理）。
    public var kind: ACPPermissionOptionKind

    public init(optionId: String, name: String, kind: ACPPermissionOptionKind) {
        self.optionId = optionId
        self.name = name
        self.kind = kind
    }
}

/// 权限选项类别。
public enum ACPPermissionOptionKind: String, Sendable, Equatable, Codable {
    /// 仅本次允许。
    case allowOnce = "allow_once"
    /// 允许并记住选择。
    case allowAlways = "allow_always"
    /// 仅本次拒绝。
    case rejectOnce = "reject_once"
    /// 拒绝并记住选择。
    case rejectAlways = "reject_always"
}

/// `session/request_permission` 响应结果（用户决定）。
public struct ACPRequestPermissionResult: Sendable, Equatable, Codable {
    /// 用户决定。
    public var outcome: ACPRequestPermissionOutcome

    public init(outcome: ACPRequestPermissionOutcome) {
        self.outcome = outcome
    }
}

/// 用户决定：取消回合或选择某个选项。
public enum ACPRequestPermissionOutcome: Sendable, Equatable {
    /// 回合被取消。
    case cancelled
    /// 用户选择了指定选项。
    case selected(optionId: String)
}

extension ACPRequestPermissionOutcome: Codable {
    private enum CodingKeys: String, CodingKey {
        case outcome, optionId
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try c.decode(String.self, forKey: .outcome)
        switch kind {
        case "cancelled":
            self = .cancelled
        case "selected":
            self = .selected(optionId: try c.decode(String.self, forKey: .optionId))
        default:
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: c.codingPath, debugDescription: "未知 permission outcome：\(kind)"))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .cancelled:
            try c.encode("cancelled", forKey: .outcome)
        case .selected(let optionId):
            try c.encode("selected", forKey: .outcome)
            try c.encode(optionId, forKey: .optionId)
        }
    }
}
