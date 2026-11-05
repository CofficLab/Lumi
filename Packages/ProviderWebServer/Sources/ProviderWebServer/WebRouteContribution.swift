import Foundation

// MARK: - Route Contribution

/// 插件贡献的一组 HTTP 路由。
///
/// 插件无需自己解析 HTTP 请求：只要声明一组 `WebRoute`，服务端就会完成
/// 路径匹配、参数解析、鉴权、错误映射与日志记录。
///
/// 贡献与插件生命周期绑定：插件被禁用或卸载时，其贡献的路由自动下线。
public struct WebRouteContribution: Sendable {
    /// 贡献的标识。同一插件重复贡献同一 id 时后者覆盖前者。
    public let id: String

    /// 贡献的路由列表。
    public let routes: [WebRoute]

    /// 创建一份路由贡献。
    ///
    /// - Parameters:
    ///   - id: 贡献标识。建议带插件前缀，如 `"theme-manager"`。
    ///   - routes: 该贡献包含的路由。
    public init(id: String, routes: [WebRoute]) {
        self.id = id
        self.routes = routes
    }
}

// MARK: - Route Contributor

/// 提供 HTTP 路由贡献的能力。
///
/// 宿主在插件启动后向所有 `WebRouteContributor` 询问路由，并聚合到 Web 服务。
/// 插件只需实现本协议并返回路由，无需关心注册、注销与生命周期。
///
/// - Note: 协议刻意 **不** 标 `@MainActor`：贡献者可能被后台线程查询。
///   实现若需要主线程状态，应自行在实现内部切换。
public protocol WebRouteContributor: Sendable {
    /// 贡献的路由列表。
    func webRoutes() -> [WebRoute]

    /// 贡献标识。用于日志与诊断；默认取插件 id。
    var webContributionID: String { get }
}

public extension WebRouteContributor {
    var webContributionID: String { "" }
}

// MARK: - Route Builder

/// 声明式构造 `WebRoute` 的构建器。
///
/// 目的是让插件写端点时不必手写 `WebRoute(id:method:path:description:handler:)`
/// 这样的长参数列表，同时保证 `id` 与 `path` 保持一致。
///
/// ```swift
/// WebRouteBuilder(id: "theme-manager")
///     .get("/themes", description: "列出全部主题") { _ in
///         try .json(["ok": true])
///     }
///     .post("/themes/:id/select", description: "切换主题") { request in
///         try .json(["id": request.pathParameters["id"] ?? ""])
///     }
/// ```
public struct WebRouteBuilder: Sendable {
    /// 路由 id 前缀。生成的路由 id 形如 `"<prefix>.<method>.<path>"`。
    public let prefix: String

    /// 已构建的路由。
    private var routes: [WebRoute]

    /// 创建构建器。
    ///
    /// - Parameter prefix: 路由 id 前缀。
    public init(prefix: String) {
        self.prefix = prefix
        self.routes = []
    }

    /// 追加一个路由。
    ///
    /// - Parameters:
    ///   - method: HTTP 方法。
    ///   - path: 路由路径。
    ///   - description: 人类可读描述，会出现在自描述端点里。
    ///   - handler: 处理器。
    /// - Returns: 构建器副本（值语义，便于链式调用）。
    public func route(
        _ method: HTTPMethod,
        _ path: String,
        description: String? = nil,
        handler: @escaping @MainActor @Sendable (WebRouteRequest) async throws -> WebRouteResponse
    ) -> WebRouteBuilder {
        var copy = self
        copy.routes.append(
            WebRoute(
                id: Self.makeRouteID(prefix: prefix, method: method, path: path),
                method: method,
                path: path,
                description: description,
                handler: handler
            )
        )
        return copy
    }

    /// 追加一个 `GET` 路由。
    public func get(
        _ path: String,
        description: String? = nil,
        handler: @escaping @MainActor @Sendable (WebRouteRequest) async throws -> WebRouteResponse
    ) -> WebRouteBuilder {
        route(.get, path, description: description, handler: handler)
    }

    /// 追加一个 `POST` 路由。
    public func post(
        _ path: String,
        description: String? = nil,
        handler: @escaping @MainActor @Sendable (WebRouteRequest) async throws -> WebRouteResponse
    ) -> WebRouteBuilder {
        route(.post, path, description: description, handler: handler)
    }

    /// 追加一个 `PUT` 路由。
    public func put(
        _ path: String,
        description: String? = nil,
        handler: @escaping @MainActor @Sendable (WebRouteRequest) async throws -> WebRouteResponse
    ) -> WebRouteBuilder {
        route(.put, path, description: description, handler: handler)
    }

    /// 追加一个 `PATCH` 路由。
    public func patch(
        _ path: String,
        description: String? = nil,
        handler: @escaping @MainActor @Sendable (WebRouteRequest) async throws -> WebRouteResponse
    ) -> WebRouteBuilder {
        route(.patch, path, description: description, handler: handler)
    }

    /// 追加一个 `DELETE` 路由。
    public func delete(
        _ path: String,
        description: String? = nil,
        handler: @escaping @MainActor @Sendable (WebRouteRequest) async throws -> WebRouteResponse
    ) -> WebRouteBuilder {
        route(.delete, path, description: description, handler: handler)
    }

    /// 构建结果。
    public func build() -> [WebRoute] {
        routes
    }

    /// 生成稳定的路由 id。
    ///
    /// 路径里的 `:` 与 `/` 会被替换，避免 id 里出现分隔符造成歧义。
    static func makeRouteID(prefix: String, method: HTTPMethod, path: String) -> String {
        let normalizedPath = path
            .split(separator: "/")
            .map { segment -> String in
                segment.hasPrefix(":") ? "by-\(segment.dropFirst())" : String(segment)
            }
            .joined(separator: "-")
        let base = prefix.isEmpty ? "route" : prefix
        return "\(base).\(method.rawValue.lowercased()).\(normalizedPath)"
    }
}
