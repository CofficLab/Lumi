import Foundation

/// 工具调用模型
///
/// 表示 AI 助手请求执行工具/函数的调用。
/// 当 AI 分析用户请求后认为需要执行某个工具时，会生成 ToolCall。
public struct ToolCall: Codable, Sendable, Equatable {
    /// 工具调用唯一标识符
    public let id: String

    /// 工具名称
    public let name: String

    /// 工具参数（JSON 字符串）
    public let arguments: String

    /// 本调用的授权状态（与模型 API 无关，仅本地持久化与 UI）
    public var authorizationState: ToolCallAuthorizationState

    public init(
        id: String,
        name: String,
        arguments: String,
        authorizationState: ToolCallAuthorizationState = .pendingAuthorization
    ) {
        self.id = id
        self.name = name
        self.arguments = arguments
        self.authorizationState = authorizationState
    }

    enum CodingKeys: String, CodingKey {
        case id, name, arguments, authorizationState
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        arguments = try c.decode(String.self, forKey: .arguments)
        authorizationState =
            try c.decodeIfPresent(ToolCallAuthorizationState.self, forKey: .authorizationState)
            ?? .pendingAuthorization
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(arguments, forKey: .arguments)
        if authorizationState != .pendingAuthorization {
            try c.encode(authorizationState, forKey: .authorizationState)
        }
    }
}
