import Foundation

/// JSON-RPC 2.0 错误对象。
///
/// 遵循标准 JSON-RPC 2.0 错误处理：成功响应含 `result`，错误响应含
/// `error`（code + message + 可选 data）。通知永不响应。
/// 参考：https://agentclientprotocol.com/protocol/overview
public struct ACPError: Codable, Sendable, Equatable {
    /// 错误码。
    public var code: Int
    /// 人类可读的错误消息。
    public var message: String
    /// 附加错误数据（可选，任意 JSON）。
    public var data: JSONValue?

    public init(code: Int, message: String, data: JSONValue? = nil) {
        self.code = code
        self.message = message
        self.data = data
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        code = try c.decode(Int.self, forKey: .code)
        message = try c.decode(String.self, forKey: .message)
        data = try c.decodeIfPresent(JSONValue.self, forKey: .data)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(code, forKey: .code)
        try c.encode(message, forKey: .message)
        try c.encodeIfPresent(data, forKey: .data)
    }

    private enum CodingKeys: String, CodingKey {
        case code, message, data
    }
}

/// JSON-RPC 2.0 标准错误码。
/// 参考：https://www.jsonrpc.org/specification
public enum ACPErrorCode {
    /// 无效 JSON（解析错误）。
    public static let parseError = -32700
    /// 请求不是合法的 JSON-RPC。
    public static let invalidRequest = -32600
    /// 方法不存在。
    public static let methodNotFound = -32601
    /// 参数无效。
    public static let invalidParams = -32602
    /// 内部错误。
    public static let internalError = -32603
    /// 请求被取消（`session/cancel` 或回合结束导致挂起请求作废）。
    /// 参考：https://agentclientprotocol.com/protocol/cancellation
    public static let requestCancelled = -32800
    /// Agent 侧等待 Client 响应超时（Lumi 自定义，用于防止 Client 无响应时悬挂）。
    public static let requestTimeout = -32801
}

public extension ACPError {
    static let parseError = ACPError(code: ACPErrorCode.parseError, message: "Parse error")
    static let invalidRequest = ACPError(code: ACPErrorCode.invalidRequest, message: "Invalid Request")
    static let methodNotFound = ACPError(code: ACPErrorCode.methodNotFound, message: "Method not found")
    static let invalidParams = ACPError(code: ACPErrorCode.invalidParams, message: "Invalid params")
    static let internalError = ACPError(code: ACPErrorCode.internalError, message: "Internal error")
}
