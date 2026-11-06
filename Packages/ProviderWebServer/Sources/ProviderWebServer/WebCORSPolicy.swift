import Foundation

// MARK: - CORS Policy

/// 跨域资源共享策略。
///
/// 本地 Web 服务默认只监听回环地址，浏览器场景下同源访问无需 CORS。
/// 但外部工具（IDE 插件、网页控制台）可能从别的源发起请求，此时需要显式
/// 声明允许的来源。
///
/// - Note: `allowedOrigin` 返回 `nil` 表示「该来源不被允许」，此时服务端
///   **不会**写入 `Access-Control-Allow-Origin` 头——浏览器据此拦截响应。
///   这比写入一个错误来源更安全：不会让调用方误以为跨域已被放行。
public struct WebCORSPolicy: Sendable, Equatable {
    /// 允许的来源。`"*"` 表示任意来源。
    public let allowedOrigins: [String]

    /// 允许的 HTTP 方法。
    public let allowedMethods: [String]

    /// 允许的请求头。
    public let allowedHeaders: [String]

    /// 是否允许携带凭据（如 Cookie）。
    ///
    /// - Important: 规范要求 `Access-Control-Allow-Credentials: true` 时
    ///   `Access-Control-Allow-Origin` **不能**是 `*`，必须回显具体来源。
    ///   本类型在 `allowedOrigins` 含 `*` 且允许凭据时，改为回显请求方来源。
    public let allowsCredentials: Bool

    /// 预检结果缓存时长（秒）。
    public let maxAge: Int?

    /// 创建 CORS 策略。
    ///
    /// - Parameters:
    ///   - allowedOrigins: 允许的来源列表，默认 `["*"]`。
    ///   - allowedMethods: 允许的方法，默认 `["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"]`。
    ///   - allowedHeaders: 允许的请求头，默认 `["Content-Type", "Authorization", "X-API-Key", "X-Request-ID"]`。
    ///   - allowsCredentials: 是否允许携带凭据，默认 `false`。
    ///   - maxAge: 预检缓存时长，默认 600 秒。
    public init(
        allowedOrigins: [String] = ["*"],
        allowedMethods: [String] = ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
        allowedHeaders: [String] = ["Content-Type", "Authorization", "X-API-Key", "X-Request-ID"],
        allowsCredentials: Bool = false,
        maxAge: Int? = 600
    ) {
        self.allowedOrigins = allowedOrigins
        self.allowedMethods = allowedMethods
        self.allowedHeaders = allowedHeaders
        self.allowsCredentials = allowsCredentials
        self.maxAge = maxAge
    }

    /// 判断给定来源是否被允许，并返回应当写入响应头的来源值。
    ///
    /// - Parameter origin: 请求头 `Origin` 的值。
    /// - Returns: 应当回显的来源；不被允许时返回 `nil`。
    public func allowedOrigin(in origin: String?) -> String? {
        guard let origin, !origin.isEmpty else { return nil }
        if allowedOrigins.contains("*") {
            // 允许凭据时不能回显 `*`，必须回显具体来源。
            return allowsCredentials ? origin : "*"
        }
        return allowedOrigins.contains(origin) ? origin : nil
    }
}
