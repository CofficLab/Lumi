import Foundation
import Hummingbird
import HTTPTypes
import KernelLumi
import NIOCore
import ServiceLifecycle

// MARK: - Error

/// 本地 Web 服务错误。
public enum LumiWebServerError: Error {
    /// 服务启动失败(如端口被占用)。
    case failedToStart(underlying: Error)
}

// MARK: - Start Gate

/// 启动单次信号:在「绑定成功」(带回环端口)或「启动失败」之间恰好唤醒一次等待者。
private final class StartGate: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Int, any Error>?

    func arm(_ continuation: CheckedContinuation<Int, any Error>) {
        lock.lock()
        self.continuation = continuation
        lock.unlock()
    }

    func succeed(withPort port: Int) {
        resume { $0.resume(returning: port) }
    }

    func fail(_ error: any Error) {
        resume { $0.resume(throwing: error) }
    }

    private func resume(_ body: (CheckedContinuation<Int, any Error>) -> Void) {
        lock.lock()
        let continuation = self.continuation
        self.continuation = nil
        lock.unlock()
        if let continuation { body(continuation) }
    }
}

// MARK: - Discovery Response

/// `GET /api/plugins` 自描述端点的响应体:列出所有已注册路由,便于调用方发现。
private struct DiscoveryResponse: Encodable {
    struct RouteInfo: Encodable {
        /// 归属插件 ID。
        let plugin: String
        /// HTTP 方法(如 "GET"、"POST")。
        let method: String
        /// 路由路径(含 `:param` 占位符)。
        let path: String
        /// 可选的人类可读描述。
        let description: String?
    }

    let routes: [RouteInfo]
}

// MARK: - Route Dispatch Middleware

/// Hummingbird 中间件:拦截所有请求,交给 `LumiWebServer` 按其路由表匹配并派发。
///
/// 作为唯一入口,使 Hummingbird 的路由器与动态路由表解耦——插件增删路由时
/// 只需更新服务端的表,无需重建 Hummingbird 路由器。
private struct RouteDispatchMiddleware: RouterMiddleware {
    typealias Context = BasicRequestContext

    weak var server: LumiWebServer?

    func handle(
        _ request: Request,
        context: BasicRequestContext,
        next: (Request, BasicRequestContext) async throws -> Response
    ) async throws -> Response {
        guard let server else { return try await next(request, context) }
        return try await server.dispatch(request: request)
    }
}

// MARK: - LumiWebServer

/// 基于 Hummingbird 的本地 Web 服务实现。
///
/// 仅监听本地回环地址(127.0.0.1),聚合插件通过 `WebServerProviding` 注册的路由。
/// 路由表用锁保护(主线程写入、后台请求线程读取);每个请求匹配到路由后,把
/// `handler` 调用派发到主线程执行(`handler` 是 `@MainActor`)。
public final class LumiWebServer: WebServerProviding, @unchecked Sendable {
    /// 配置的监听端口。
    public let port: Int
    /// 实际绑定端口(启动成功后才有意义)。
    public private(set) var boundPort: Int?
    /// 是否正在监听。
    public private(set) var isRunning: Bool = false

    /// 仅监听回环地址,避免暴露到局域网。
    private let host = "127.0.0.1"
    /// 请求体最大字节数,防止超大请求耗尽内存。
    private let maxBodySize: Int
    /// 可选鉴权 token。非 nil 时要求请求头 `Authorization: Bearer <token>`。
    private let authToken: String?
    /// 内置自描述端点路径:GET 之即返回所有已注册路由的清单。
    private static let discoveryPath = "/api/plugins"
    /// 已绑定的 Hummingbird 应用的服务组(用于停止)。
    private var serviceGroup: ServiceGroup?
    /// 运行服务组的后台任务。
    private var runTask: Task<Void, Never>?

    // 路由表(pluginID -> routes),与派发用的扁平匹配器列表,统一用锁保护。
    private let lock = NSLock()
    private var routesByPlugin: [String: [WebRoute]] = [:]
    private var matchers: [(route: WebRoute, matcher: RouteMatcher)] = []

    /// - Parameters:
    ///   - port: 监听端口(默认 7310)。
    ///   - authToken: 可选鉴权 token。
    ///   - maxBodySize: 请求体最大字节数(默认 1 MiB)。
    public init(port: Int = 7310, authToken: String? = nil, maxBodySize: Int = 1_048_576) {
        self.port = port
        self.authToken = authToken
        self.maxBodySize = maxBodySize
    }

    // MARK: WebServerProviding - Route Registration

    public func register(_ routes: [WebRoute], forPlugin pluginID: String) {
        lock.lock()
        routesByPlugin[pluginID] = routes
        rebuildMatchersLocked()
        lock.unlock()
    }

    public func unregister(pluginID: String) {
        lock.lock()
        routesByPlugin.removeValue(forKey: pluginID)
        rebuildMatchersLocked()
        lock.unlock()
    }

    private func rebuildMatchersLocked() {
        matchers = routesByPlugin
            .values
            .flatMap { $0 }
            .map { (route: $0, matcher: RouteMatcher(template: $0.path)) }
    }

    // MARK: WebServerProviding - Lifecycle

    public func start() async throws {
        guard !isRunning else { return }

        let gate = StartGate()
        let router = Router()
        router.middlewares.add(RouteDispatchMiddleware(server: self))

        let app = Application(
            responder: router.buildResponder(),
            configuration: .init(address: .hostname(host, port: port)),
            onServerRunning: { channel in
                if let port = channel.localAddress?.port {
                    gate.succeed(withPort: port)
                }
            }
        )

        let group = ServiceGroup(
            configuration: .init(services: [app], logger: app.logger)
        )
        self.serviceGroup = group

        let runTask = Task {
            do {
                try await group.run()
            } catch {
                gate.fail(LumiWebServerError.failedToStart(underlying: error))
            }
        }
        self.runTask = runTask

        do {
            // 等待服务真正绑定端口;若启动期间出错(如端口被占用)则抛出。
            let actualPort = try await withCheckedThrowingContinuation { continuation in
                gate.arm(continuation)
            }
            self.boundPort = actualPort
            self.isRunning = true
        } catch {
            await stop()
            throw error
        }
    }

    public func stop() async {
        guard isRunning else { return }
        isRunning = false
        let group = serviceGroup
        serviceGroup = nil
        if let group {
            await group.triggerGracefulShutdown()
            _ = await runTask?.value
        }
        runTask = nil
        boundPort = nil
    }

    // MARK: Request Dispatch

    /// 处理一个 HTTP 请求:校验鉴权 → 匹配路由 → 在主线程执行 handler → 返回响应。
    func dispatch(request: Request) async throws -> Response {
        // 鉴权
        if let authToken {
            let provided = request.headers[.authorization] ?? ""
            let bearer = provided.hasPrefix("Bearer ") ? String(provided.dropFirst("Bearer ".count)) : provided
            guard bearer == authToken else {
                return Self.makeResponse(status: .unauthorized, message: "Unauthorized")
            }
        }

        // 方法(HTTPTypes.Method -> 内核 HTTPMethod)
        guard let method = HTTPMethod(rawValue: request.method.rawValue) else {
            return Self.makeResponse(status: .methodNotAllowed, message: "Method Not Allowed")
        }

        let path = request.uri.path

        // 内置自描述端点:GET /api/plugins,实时列出所有已注册路由(无需读取请求体)。
        if method == .get, path == Self.discoveryPath {
            let infos = discoveryRouteInfos()
            let webResponse = try WebRouteResponse.json(DiscoveryResponse(routes: infos))
            return Self.makeResponse(from: webResponse)
        }

        // 请求体
        var collated = request
        let buffer = try await collated.collectBody(upTo: maxBodySize)
        var bodyData = Data()
        bodyData.append(contentsOf: buffer.readableBytesView)

        // 路由匹配
        guard let matched = matchRoute(method: method, path: path) else {
            return Self.makeResponse(status: .notFound, message: "Not Found")
        }

        // 请求头(小写归一)
        var headers: [String: String] = [:]
        for field in request.headers {
            headers[field.name.description.lowercased()] = field.value
        }

        let webRequest = WebRouteRequest(
            method: method,
            path: path,
            pathParameters: matched.parameters,
            queryParameters: Self.parseQuery(request.uri.query),
            headers: headers,
            body: bodyData
        )

        // 执行 handler(自动 hop 到主线程)。
        let result: WebRouteResponse
        do {
            result = try await matched.route.handler(webRequest)
        } catch {
            let message = error.localizedDescription
            return Self.makeResponse(status: .internalServerError, message: message)
        }

        return Self.makeResponse(from: result)
    }

    // MARK: - Helpers

    private func matchRoute(method: HTTPMethod, path: String) -> (route: WebRoute, parameters: [String: String])? {
        let snapshot: [(route: WebRoute, matcher: RouteMatcher)] = {
            lock.lock(); defer { lock.unlock() }
            return matchers
        }()
        for entry in snapshot {
            guard entry.route.method == method else { continue }
            if let parameters = entry.matcher.match(path) {
                return (route: entry.route, parameters: parameters)
            }
        }
        return nil
    }

    /// 枚举当前所有已注册路由,供自描述端点 `GET /api/plugins` 返回。
    private func discoveryRouteInfos() -> [DiscoveryResponse.RouteInfo] {
        lock.lock(); defer { lock.unlock() }
        return routesByPlugin.flatMap { (pluginID, routes) in
            routes.map { route in
                DiscoveryResponse.RouteInfo(
                    plugin: pluginID,
                    method: route.method.rawValue,
                    path: route.path,
                    description: route.description
                )
            }
        }
    }

    private static func parseQuery(_ query: String?) -> [String: String] {
        guard let query, !query.isEmpty else { return [:] }
        var result: [String: String] = [:]
        for pair in query.split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1)
            let rawKey = String(parts[0])
            let key = rawKey.removingPercentEncoding ?? rawKey
            if parts.count == 2 {
                let rawValue = String(parts[1])
                result[key] = rawValue.removingPercentEncoding ?? rawValue
            } else {
                result[key] = ""
            }
        }
        return result
    }

    private static func makeResponse(from webResponse: WebRouteResponse) -> Response {
        var buffer = ByteBufferAllocator().buffer(capacity: webResponse.body.count)
        buffer.writeBytes(webResponse.body)
        var response = Response(
            status: HTTPResponse.Status(code: webResponse.statusCode),
            body: ResponseBody(byteBuffer: buffer)
        )
        for (name, value) in webResponse.headers {
            if let fieldName = HTTPField.Name(name) {
                response.headers[fieldName] = value
            }
        }
        return response
    }

    private static func makeResponse(status: HTTPResponse.Status, message: String) -> Response {
        var buffer = ByteBufferAllocator().buffer(capacity: message.utf8.count)
        buffer.writeString(message)
        var response = Response(
            status: status,
            body: ResponseBody(byteBuffer: buffer)
        )
        response.headers[.contentType] = "text/plain; charset=utf-8"
        return response
    }
}
