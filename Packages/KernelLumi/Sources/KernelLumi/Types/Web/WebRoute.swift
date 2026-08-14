import Foundation

// MARK: - Web Route Request

/// 服务端解析后的路由请求,交给插件处理器。
///
/// 由 Web 服务在匹配到路由后构造:已从路由模板 `:param` 占位符解析出
/// `pathParameters`,并归一化 query / headers。该类型为纯值类型且 `Sendable`,
/// 可安全跨线程传递(从网络工作线程送到主线程执行处理器)。
public struct WebRouteRequest: Sendable {
    /// 命中的 HTTP 方法。
    public let method: HTTPMethod

    /// 原始请求路径(不含 query string)。
    public let path: String

    /// 从路由模板 `:param` 占位符解析出的参数。
    ///
    /// 例如模板 `/api/theme/:id` 命中 `/api/theme/dark` 时,该值为 `["id": "dark"]`。
    public let pathParameters: [String: String]

    /// 查询参数(已 URL 解码)。
    public let queryParameters: [String: String]

    /// 请求头,key 已归一化为小写。
    public let headers: [String: String]

    /// 请求体原始字节(可能为空)。
    public let body: Data

    public init(
        method: HTTPMethod,
        path: String,
        pathParameters: [String: String] = [:],
        queryParameters: [String: String] = [:],
        headers: [String: String] = [:],
        body: Data = Data()
    ) {
        self.method = method
        self.path = path
        self.pathParameters = pathParameters
        self.queryParameters = queryParameters
        self.headers = headers
        self.body = body
    }

    /// 把 JSON 请求体解码为指定类型。
    public func decodeBody<T: Decodable>(as type: T.Type = T.self) throws -> T {
        try JSONDecoder().decode(T.self, from: body)
    }
}

// MARK: - Web Route Response

/// 路由处理器返回的响应。
public struct WebRouteResponse: Sendable {
    /// HTTP 状态码。
    public let statusCode: Int

    /// 响应头,key 建议归一化为小写。
    public let headers: [String: String]

    /// 响应体。
    public let body: Data

    public init(statusCode: Int, headers: [String: String] = [:], body: Data = Data()) {
        self.statusCode = statusCode
        self.headers = headers
        self.body = body
    }

    /// 返回 JSON 响应(自动设置 `Content-Type: application/json`)。
    public static func json<T: Encodable>(
        _ value: T,
        statusCode: Int = 200,
        extraHeaders: [String: String] = [:]
    ) throws -> WebRouteResponse {
        let data = try JSONEncoder().encode(value)
        var headers = extraHeaders
        headers["Content-Type"] = "application/json"
        return WebRouteResponse(statusCode: statusCode, headers: headers, body: data)
    }

    /// 纯文本响应。
    public static func text(_ string: String, statusCode: Int = 200) -> WebRouteResponse {
        let headers = ["Content-Type": "text/plain; charset=utf-8"]
        return WebRouteResponse(statusCode: statusCode, headers: headers, body: Data(string.utf8))
    }

    /// 404 Not Found。
    public static let notFound = WebRouteResponse(statusCode: 404, body: Data("Not Found".utf8))

    /// 405 Method Not Allowed。
    public static let methodNotAllowed = WebRouteResponse(statusCode: 405, body: Data("Method Not Allowed".utf8))
}

// MARK: - Web Route

/// 一个由插件声明式贡献的 HTTP 路由。
///
/// 插件通过 `LumiPlugin.webRoutes(kernel:)` 返回若干 `WebRoute`,由内核聚合到
/// 本地 Web 服务(默认仅监听 127.0.0.1)。处理器运行在**主线程**上,因此可直接
/// 调用 `kernel` 上以 `@MainActor` 暴露的服务(如 `kernel.theme`),无需手动切换
/// actor——服务端在调用 `handler` 时会自动 hop 到主线程。
///
/// - Important: `id` 需稳定唯一,建议带插件前缀(如 `"theme-manager.switch"`),
///   以便插件在运行时启用/禁用时内核能按插件整体替换其路由。
public struct WebRoute: Identifiable, Sendable {
    /// 稳定唯一标识,建议带插件前缀。
    public let id: String

    /// HTTP 方法。
    public let method: HTTPMethod

    /// 路由路径,以 `/` 开头;支持 `:param` 占位符(如 `/api/theme/:id`)。
    public let path: String

    /// 可选的人类可读描述,用于自描述端点 `GET /api/plugins` 展示,便于调用方发现。
    public let description: String?

    /// 处理器。运行在主线程上,可直接调用 `@MainActor` 服务。
    public let handler: @MainActor @Sendable (WebRouteRequest) async throws -> WebRouteResponse

    /// 创建一个不带描述的路由(等价于 `description: nil`)。
    public init(
        id: String,
        method: HTTPMethod,
        path: String,
        handler: @escaping @MainActor @Sendable (WebRouteRequest) async throws -> WebRouteResponse
    ) {
        self.init(id: id, method: method, path: path, description: nil, handler: handler)
    }

    /// 创建一个带描述的路由。`description` 会出现在自描述端点的路由列表中。
    public init(
        id: String,
        method: HTTPMethod,
        path: String,
        description: String?,
        handler: @escaping @MainActor @Sendable (WebRouteRequest) async throws -> WebRouteResponse
    ) {
        self.id = id
        self.method = method
        self.path = path
        self.description = description
        self.handler = handler
    }
}
