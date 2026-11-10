import Foundation

// MARK: - API Version

/// Web API 版本。
///
/// 外部调用方通过路径前缀区分版本（如 `/api/v1/status`）。版本前缀本身不做
/// 路由拦截——它是**约定**而非强制：插件可以自由声明任意路径，但核心控制面
/// 端点统一使用当前版本前缀，便于调用方发现与演进。
public enum WebAPIVersion: String, Sendable, CaseIterable, Codable {
    case v1 = "v1"

    /// 该版本的路径前缀（如 `/api/v1`）。
    public var prefix: String { "/api/\(rawValue)" }

    /// 当前默认版本。新增破坏性变更时引入新枚举值，而不是原地改语义。
    public static let current: WebAPIVersion = .v1
}

// MARK: - API Error

/// 统一的 API 错误。
///
/// 插件处理器通过抛出该错误表达「预期内的失败」，服务端负责把它映射成
/// 正确的 HTTP 状态码与统一的 JSON 错误体。未被识别的错误一律按 500 处理，
/// 且**不回显内部细节**，避免把实现细节或路径泄露给外部调用方。
public enum WebAPIError: Error, Sendable, Equatable {
    /// 请求参数不合法（400）。
    case badRequest(message: String, field: String? = nil)
    /// 缺少或无效的鉴权凭证（401）。
    case unauthorized(message: String = "Missing or invalid credentials")
    /// 已鉴权但无权执行（403）。
    case forbidden(message: String)
    /// 目标不存在（404）。
    case notFound(message: String = "Resource not found")
    /// 路径存在但方法不支持（405）。
    case methodNotAllowed(message: String = "Method not allowed")
    /// 与当前状态冲突（409）。
    case conflict(message: String)
    /// 请求体超出大小限制（413）。
    case payloadTooLarge(message: String = "Request body is too large")
    /// 请求体类型不受支持（415）。
    case unsupportedMediaType(message: String = "Unsupported media type")
    /// 服务内部错误（500）。
    case internalError(message: String = "Internal server error")
    /// 服务暂时不可用（503）。
    case unavailable(message: String = "Service unavailable")
    /// 处理超时（504）。
    case timeout(message: String = "Request timed out")

    /// 对应的 HTTP 状态码。
    public var statusCode: Int {
        switch self {
        case .badRequest: return 400
        case .unauthorized: return 401
        case .forbidden: return 403
        case .notFound: return 404
        case .methodNotAllowed: return 405
        case .conflict: return 409
        case .payloadTooLarge: return 413
        case .unsupportedMediaType: return 415
        case .internalError: return 500
        case .unavailable: return 503
        case .timeout: return 504
        }
    }

    /// 稳定的机器可读错误码。调用方应据此分支，而不是解析 `message`。
    public var code: String {
        switch self {
        case .badRequest: return "bad_request"
        case .unauthorized: return "unauthorized"
        case .forbidden: return "forbidden"
        case .notFound: return "not_found"
        case .methodNotAllowed: return "method_not_allowed"
        case .conflict: return "conflict"
        case .payloadTooLarge: return "payload_too_large"
        case .unsupportedMediaType: return "unsupported_media_type"
        case .internalError: return "internal_error"
        case .unavailable: return "unavailable"
        case .timeout: return "timeout"
        }
    }

    /// 面向调用方的错误说明。
    public var message: String {
        switch self {
        case .badRequest(let message, _): return message
        case .unauthorized(let message): return message
        case .forbidden(let message): return message
        case .notFound(let message): return message
        case .methodNotAllowed(let message): return message
        case .conflict(let message): return message
        case .payloadTooLarge(let message): return message
        case .unsupportedMediaType(let message): return message
        case .internalError(let message): return message
        case .unavailable(let message): return message
        case .timeout(let message): return message
        }
    }

    /// 出错的具体字段名（如请求体字段缺失）。
    public var field: String? {
        if case .badRequest(_, let field) = self { return field }
        return nil
    }
}

// MARK: - Error Body

/// 统一的 JSON 错误响应体。
///
/// 固定形状让调用方可以用一套解析逻辑处理所有失败：
/// `{"error": {"code": "...", "message": "...", "field": "...", "requestID": "..."}}`
public struct WebErrorResponse: Codable, Sendable {
    /// 错误详情。
    public struct Body: Codable, Sendable {
        /// 机器可读错误码（见 `WebAPIError.code`）。
        public let code: String
        /// 面向调用方的说明。
        public let message: String
        /// 出错字段（可选）。
        public let field: String?
        /// 本次请求的追踪 ID，便于在服务端日志中定位。
        public let requestID: String?

        public init(code: String, message: String, field: String? = nil, requestID: String? = nil) {
            self.code = code
            self.message = message
            self.field = field
            self.requestID = requestID
        }
    }

    /// 错误详情。
    public let error: Body

    public init(_ error: WebAPIError, requestID: String? = nil) {
        self.error = Body(
            code: error.code,
            message: error.message,
            field: error.field,
            requestID: requestID
        )
    }
}

// MARK: - Success Envelope

/// 统一的 JSON 成功响应包装。
///
/// 与 `WebErrorResponse` 对称：成功时是 `{"data": ..., "requestID": ...}`，
/// 失败时是 `{"error": {...}}`。`data` 直接承载业务负载，调用方无需再解一层。
public struct WebAPIEnvelope<Value: Encodable & Sendable>: Encodable, Sendable {
    /// 业务负载。
    public let data: Value
    /// 本次请求的追踪 ID。
    public let requestID: String?
    /// 响应所遵循的 API 版本。
    public let version: String

    public init(data: Value, requestID: String? = nil, version: WebAPIVersion = .current) {
        self.data = data
        self.requestID = requestID
        self.version = version.rawValue
    }
}

/// 可解码的成功信封。
///
/// 与 `WebAPIEnvelope` 形状相同，但要求业务负载同时可解码——供测试与
/// 客户端复用同一套解析逻辑。
public struct WebAPIDecodableEnvelope<Value: Decodable & Sendable>: Decodable, Sendable {
    /// 业务负载。
    public let data: Value
    /// 本次请求的追踪 ID。
    public let requestID: String?
    /// 响应所遵循的 API 版本。
    public let version: String

    public init(data: Value, requestID: String? = nil, version: WebAPIVersion = .current) {
        self.data = data
        self.requestID = requestID
        self.version = version.rawValue
    }
}
