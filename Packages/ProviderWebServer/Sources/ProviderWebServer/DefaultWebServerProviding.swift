import Foundation

/// `WebServerProviding` 的内存默认实现。
///
/// 提供最基本的路由聚合能力（无真实套接字监听）：
/// 按插件维护线程安全的路由表，支持 `:param` 占位符匹配，并在主线程执行
/// 命中路由的处理器。`start()` / `stop()` 仅切换运行状态。
/// 需要真实 HTTP 监听等完整能力的宿主应提供自己的实现替换。
public final class DefaultWebServerProviding: WebServerProviding, @unchecked Sendable {
    private let lock = NSLock()
    private var routesByPlugin: [String: [WebRoute]] = [:]
    private var _isRunning = false
    private var observers: [UUID: @Sendable (WebServerEvent) -> Void] = [:]

    /// 配置端口。骨架实现不真实绑定端口,启动后仍返回此值。
    public let port: Int
    /// 路由处理完成后的活动事件；宿主可据此显示写操作反馈。
    public let onActivity: (@Sendable (WebRequestActivity) -> Void)?

    public init(
        port: Int = 8765,
        onActivity: (@Sendable (WebRequestActivity) -> Void)? = nil
    ) {
        self.port = port
        self.onActivity = onActivity
    }

    public var isRunning: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isRunning
    }

    public func register(_ routes: [WebRoute], forPlugin pluginID: String) {
        lock.lock()
        if routes.isEmpty {
            routesByPlugin[pluginID] = nil
        } else {
            routesByPlugin[pluginID] = routes
        }
        lock.unlock()
        notify(.routesChanged(pluginID: pluginID))
    }

    public func unregister(pluginID: String) {
        lock.lock()
        routesByPlugin[pluginID] = nil
        lock.unlock()
        notify(.routesChanged(pluginID: pluginID))
    }

    public func start() async throws {
        setRunning(true)
        // 骨架阶段：不真实绑定端口，仅维护运行状态。
    }

    public func stop() async {
        setRunning(false)
    }

    /// 同步更新运行状态（async 方法体内不可直接调用 NSLock，故提取为同步函数）。
    private func setRunning(_ running: Bool) {
        lock.lock()
        guard _isRunning != running else {
            lock.unlock()
            return
        }
        _isRunning = running
        lock.unlock()
        notify(running ? .started(port: port) : .stopped)
    }

    @discardableResult
    public func addWebServerObserver(_ callback: @escaping @Sendable (WebServerEvent) -> Void) -> any WebServerObserverHandle {
        let id = UUID()
        lock.lock()
        observers[id] = callback
        lock.unlock()
        return DefaultWebServerObserverHandle { [weak self] in
            self?.lock.lock()
            self?.observers.removeValue(forKey: id)
            self?.lock.unlock()
        }
    }

    private func notify(_ event: WebServerEvent) {
        lock.lock()
        let callbacks = Array(observers.values)
        lock.unlock()
        for callback in callbacks {
            callback(event)
        }
    }

    // MARK: - Request Handling

    /// 匹配并处理一个请求（协议外能力，供无网络层的演示与测试使用）。
    ///
    /// 路由表在锁内读取；命中后处理器在 **主线程** 上执行
    /// （`WebRoute.handler` 为 `@MainActor` 闭包，async 调用会自动 hop）。
    /// 路径匹配但方法不匹配时返回 405，无匹配返回 404。
    public func handle(_ request: WebRouteRequest) async throws -> WebRouteResponse {
        let routeAndParams = match(request)
        switch routeAndParams {
        case .matched(let route, let pathParameters, let pluginID):
            let routedRequest = WebRouteRequest(
                method: request.method,
                path: request.path,
                pathParameters: pathParameters,
                queryParameters: request.queryParameters,
                headers: request.headers,
                body: request.body
            )
            let response = try await route.handler(routedRequest)
            onActivity?(WebRequestActivity(
                pluginID: pluginID,
                method: route.method.rawValue,
                path: route.path,
                description: route.description,
                statusCode: response.statusCode
            ))
            return response
        case .methodNotAllowed:
            return .methodNotAllowed
        case .notFound:
            return .notFound
        }
    }

    private enum MatchResult {
        case matched(WebRoute, [String: String], String)
        case methodNotAllowed
        case notFound
    }

    private func match(_ request: WebRouteRequest) -> MatchResult {
        lock.lock()
        defer { lock.unlock() }
        var pathMatchedButMethodWrong = false
        for (pluginID, routes) in routesByPlugin {
            for route in routes {
            guard let pathParameters = Self.match(pathTemplate: route.path, requestPath: request.path) else {
                continue
            }
            if route.method == request.method {
                return .matched(route, pathParameters, pluginID)
            }
            pathMatchedButMethodWrong = true
            }
        }
        return pathMatchedButMethodWrong ? .methodNotAllowed : .notFound
    }

    /// 把请求路径按模板匹配，`/api/theme/:id` 命中 `/api/theme/dark` 时返回 `["id": "dark"]`。
    private static func match(pathTemplate: String, requestPath: String) -> [String: String]? {
        let templateSegments = pathTemplate.split(separator: "/").map(String.init)
        let requestSegments = requestPath.split(separator: "/").map(String.init)
        guard templateSegments.count == requestSegments.count else { return nil }

        var parameters: [String: String] = [:]
        for (template, request) in zip(templateSegments, requestSegments) {
            if template.hasPrefix(":") {
                parameters[String(template.dropFirst())] = request
            } else if template != request {
                return nil
            }
        }
        return parameters
    }
}

private final class DefaultWebServerObserverHandle: WebServerObserverHandle, @unchecked Sendable {
    private let cancellation: @Sendable () -> Void
    private let lock = NSLock()
    private var isCancelled = false

    init(cancellation: @escaping @Sendable () -> Void) {
        self.cancellation = cancellation
    }

    func cancel() {
        lock.lock()
        guard !isCancelled else {
            lock.unlock()
            return
        }
        isCancelled = true
        lock.unlock()
        cancellation()
    }
}
