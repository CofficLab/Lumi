import Foundation

/// ACP 消息信封（JSON-RPC 2.0）。
///
/// 四种形态：request / response / notification / error response。
/// - request 与 response 携带 `id`；
/// - notification 无 `id`、无响应；
/// - response 中 `result` 与 `error` 互斥。
///
/// 参考：https://agentclientprotocol.com/protocol/overview
public enum ACPMessage: Sendable, Equatable {
    /// 请求（期望响应）。
    case request(id: JSONValue, method: String, params: JSONValue?)
    /// 成功响应。
    case response(id: JSONValue, result: JSONValue?)
    /// 错误响应。
    case error(id: JSONValue, error: ACPError)
    /// 通知（无响应）。
    case notification(method: String, params: JSONValue?)
}

public extension ACPMessage {
    /// 构造类型化请求。
    static func makeRequest<Params: Encodable>(
        id: Int,
        method: String,
        params: Params
    ) throws -> ACPMessage {
        .request(id: .number(Double(id)), method: method, params: try JSONValue.stringify(params))
    }

    /// 构造类型化通知。
    static func makeNotification<Params: Encodable>(
        method: String,
        params: Params
    ) throws -> ACPMessage {
        .notification(method: method, params: try JSONValue.stringify(params))
    }

    /// 构造类型化成功响应。
    static func makeResponse<Result: Encodable>(
        id: JSONValue,
        result: Result
    ) throws -> ACPMessage {
        .response(id: id, result: try JSONValue.stringify(result))
    }

    /// 方法名（request / notification 可用）。
    var method: String? {
        switch self {
        case .request(_, let m, _), .notification(let m, _):
            return m
        default:
            return nil
        }
    }

    /// 请求 ID（request / response / error 可用）。
    var id: JSONValue? {
        switch self {
        case .request(let id, _, _), .response(let id, _), .error(let id, _):
            return id
        default:
            return nil
        }
    }
}

// MARK: - Codable

extension ACPMessage: Codable {
    private enum CodingKeys: String, CodingKey {
        case jsonrpc, id, method, params, result, error
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let version = try c.decode(String.self, forKey: .jsonrpc)
        guard version == "2.0" else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: c.codingPath, debugDescription: "不支持的 JSON-RPC 版本：\(version)"))
        }
        let hasID = c.contains(.id)
        let hasMethod = c.contains(.method)

        switch (hasID, hasMethod) {
        case (true, true):
            // request
            let id = try c.decode(JSONValue.self, forKey: .id)
            let method = try c.decode(String.self, forKey: .method)
            let params = try c.decodeIfPresent(JSONValue.self, forKey: .params)
            self = .request(id: id, method: method, params: params)
        case (false, true):
            // notification
            let method = try c.decode(String.self, forKey: .method)
            let params = try c.decodeIfPresent(JSONValue.self, forKey: .params)
            self = .notification(method: method, params: params)
        case (true, false):
            // response 或 error
            let id = try c.decode(JSONValue.self, forKey: .id)
            if let error = try? c.decode(ACPError.self, forKey: .error) {
                self = .error(id: id, error: error)
            } else {
                // 注意：JSON-RPC 中 result 字段存在但为 null 是合法响应（如 fs/write_text_file 成功）。
                // 必须用 decode 而非 decodeIfPresent，否则 null 会被吞成 nil。
                let result: JSONValue?
                if c.contains(.result) {
                    result = try c.decode(JSONValue.self, forKey: .result)
                } else {
                    result = nil
                }
                self = .response(id: id, result: result)
            }
        case (false, false):
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: c.codingPath, debugDescription: "消息必须携带 id（request/response）或 method（request/notification）"))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode("2.0", forKey: .jsonrpc)
        switch self {
        case .request(let id, let method, let params):
            try c.encode(id, forKey: .id)
            try c.encode(method, forKey: .method)
            try c.encodeIfPresent(params, forKey: .params)
        case .response(let id, let result):
            try c.encode(id, forKey: .id)
            try c.encodeIfPresent(result, forKey: .result)
        case .error(let id, let error):
            try c.encode(id, forKey: .id)
            try c.encode(error, forKey: .error)
        case .notification(let method, let params):
            try c.encode(method, forKey: .method)
            try c.encodeIfPresent(params, forKey: .params)
        }
    }
}

// MARK: - 编解码便捷

public extension ACPMessage {
    /// 将消息编码为 UTF-8 数据（stdio 帧载荷）。
    func encodedData(using encoder: JSONEncoder = JSONEncoder()) throws -> Data {
        try encoder.encode(self)
    }

    /// 从 UTF-8 数据解码消息。
    static func decode(_ data: Data, using decoder: JSONDecoder = JSONDecoder()) throws -> ACPMessage {
        try decoder.decode(ACPMessage.self, from: data)
    }
}
