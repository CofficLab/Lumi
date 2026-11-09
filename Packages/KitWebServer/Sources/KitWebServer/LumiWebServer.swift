import Foundation
import Hummingbird
import HTTPTypes
import ProviderWebServer
import NIOCore
import ServiceLifecycle
import os

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
        /// 路由 id。
        let id: String
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
///
/// ## 请求处理管线
///
/// 每个请求依次经过:
/// 1. **请求 ID** —— 生成/透传 `X-Request-ID`,写入响应头,便于日志关联。
/// 2. **CORS 预检** —— `OPTIONS` 请求直接返回允许的方法与请求头。
/// 3. **鉴权** —— 按 `authPolicy` 校验凭证,不通过则 401。
/// 4. **跨源写保护** —— 浏览器发起的跨源写请求直接 403;无 Origin 的原生客户端放行。
/// 5. **路由匹配** —— 命中则执行 handler;未命中 404;路径匹配但方法不符 405。
/// 6. **错误映射** —— `WebAPIError` 映射为对应状态码与统一 JSON 错误体。
/// 7. **请求日志** —— 记录方法、路径、状态码与耗时(不含请求体与响应体)。
public final class LumiWebServer: WebServerExtendedProviding, @unchecked Sendable {
    /// 服务日志。
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.web-server",
        category: "WebServer"
    )

    /// 日志前缀。
    nonisolated static var t: String { "[WebServer] " }

    // 常用请求/响应头名。`HTTPField.Name` 的初始化是可失败的,这里集中定义
    // 已知合法的名字,避免在热路径上反复做可失败初始化。
    private static let requestIDHeader = HTTPField.Name("X-Request-ID")!
    private static let allowOriginHeader = HTTPField.Name("Access-Control-Allow-Origin")!
    private static let allowMethodsHeader = HTTPField.Name("Access-Control-Allow-Methods")!
    private static let allowHeadersHeader = HTTPField.Name("Access-Control-Allow-Headers")!
    private static let allowCredentialsHeader = HTTPField.Name("Access-Control-Allow-Credentials")!
    private static let maxAgeHeader = HTTPField.Name("Access-Control-Max-Age")!

    /// 配置的监听端口。
    public let port: Int
    /// 实际绑定端口(启动成功后才有意义)。
    public private(set) var boundPort: Int?
    /// 是否正在监听。
    public private(set) var isRunning: Bool = false

    /// 当前监听地址。默认仅监听回环地址,避免暴露到局域网。
    public let listenHost = "127.0.0.1"
    /// 请求体最大字节数,防止超大请求耗尽内存。
    private let maxBodySize: Int
    /// 内置自描述端点路径:GET 之即返回所有已注册路由的清单。
    private static let discoveryPath = "/api/plugins"
    /// 已绑定的 Hummingbird 应用的服务组(用于停止)。
    private var serviceGroup: ServiceGroup?
    /// 运行服务组的后台任务。
    private var runTask: Task<Void, Never>?
    /// 服务启动时刻，用于计算运行时长。
    private var startedAt: Date?

    /// 生命周期阶段，串行化 start/stop 的重叠调用。
    private enum LifecyclePhase {
        case idle
        case starting
        case running
        case stopping
    }

    private let lifecycleLock = NSLock()
    private var lifecyclePhase: LifecyclePhase = .idle
    /// 进行中的启动任务；stop 会等待它结束后再关闭服务组。
    private var startupTask: Task<Int, Error>?
    /// 进行中的关闭任务；并发的 stop 会等待同一个关闭任务。
    private var shutdownTask: Task<Void, Never>?
    /// 生命周期轮次；每次 start 递增，用于识别「已被后续 start 取代」的旧启动。
    private var lifecycleGeneration = 0
    /// 测试用启动延迟，便于确定性地覆盖启动/停止重叠路径。
    var startupDelayForTesting: Duration = .zero

    // 路由表(pluginID -> routes)与派发用的扁平匹配器列表,统一用锁保护。
    private let lock = NSLock()
    private var routesByPlugin: [String: [WebRoute]] = [:]
    private var matchers: [(route: WebRoute, matcher: RouteMatcher, pluginID: String)] = []

    /// 鉴权策略。在锁外读取的快照,避免处理器与写锁竞争。
    private let policyLock = NSLock()
    private var _authPolicy: WebAuthPolicy = .none
    private var _requestLogSink: (any WebRequestLogSink)?

    /// 请求处理完成后的活动回调(可选)。每次成功匹配并执行路由后调用一次,
    /// 携带 method/path/pluginID/description/状态码,供宿主做 UI 反馈(toast)。
    /// 在 init 时设置一次,故为 `let`,无线程安全问题。
    public let onActivity: (@Sendable (WebRequestActivity) -> Void)?

    /// 跨域资源共享策略。为 `nil` 时不返回 CORS 头(默认仅本机回环访问,无需 CORS)。
    private let corsPolicy: WebCORSPolicy?

    /// 当前已注册的路由数量,供状态页和诊断信息使用。
    public var registeredRouteCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return routesByPlugin.values.reduce(0) { $0 + $1.count }
    }

    /// 服务已运行时长（秒）。未运行时为 0。
    public var uptime: TimeInterval {
        guard let startedAt else { return 0 }
        return Date().timeIntervalSince(startedAt)
    }

    /// 是否配置了请求鉴权。
    public var hasAuthentication: Bool {
        let policy = authPolicy
        return !policy.allowsAnonymous || !policy.schemes.isEmpty
    }

    /// 当前生效的鉴权策略。
    public var authPolicy: WebAuthPolicy {
        policyLock.lock()
        defer { policyLock.unlock() }
        return _authPolicy
    }

    /// 请求日志接收端。
    public var requestLogSink: (any WebRequestLogSink)? {
        policyLock.lock()
        defer { policyLock.unlock() }
        return _requestLogSink
    }

    /// - Parameters:
    ///   - port: 监听端口(默认 7310)。
    ///   - authToken: 可选鉴权 token。非 nil 时要求请求头 `Authorization: Bearer <token>`。
    ///   - maxBodySize: 请求体最大字节数(默认 1 MiB)。
    ///   - onActivity: 可选的请求完成回调,用于 UI 反馈等。
    ///   - corsPolicy: 可选的跨域策略。
    public init(
        port: Int = 7310,
        authToken: String? = nil,
        maxBodySize: Int = 1_048_576,
        onActivity: (@Sendable (WebRequestActivity) -> Void)? = nil,
        corsPolicy: WebCORSPolicy? = nil
    ) {
        self.port = port
        self.maxBodySize = maxBodySize
        self.onActivity = onActivity
        self.corsPolicy = corsPolicy

        if let authToken {
            // 传入 token 即启用 Bearer 鉴权;调用方仍可随后用 setAuthPolicy 调整。
            var store = WebCredentialStore()
            store.add(authToken, for: .bearer)
            let policy = store.policy(schemes: [.bearer], allowsAnonymous: false)
            policyLock.lock()
            _authPolicy = policy
            policyLock.unlock()
        }
    }

    // MARK: WebServerProviding - Route Registration

    public func register(_ routes: [WebRoute], forPlugin pluginID: String) {
        lock.lock()
        if routes.isEmpty {
            routesByPlugin.removeValue(forKey: pluginID)
        } else {
            routesByPlugin[pluginID] = routes
        }
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
        matchers = routesByPlugin.flatMap { (pluginID, routes) in
            routes.map { (route: $0, matcher: RouteMatcher(template: $0.path), pluginID: pluginID) }
        }
    }

    // MARK: WebServerExtendedProviding - Auth & Logging

    public func setAuthPolicy(_ policy: WebAuthPolicy) {
        policyLock.lock()
        _authPolicy = policy
        policyLock.unlock()
    }

    public func setRequestLogSink(_ sink: (any WebRequestLogSink)?) {
        policyLock.lock()
        _requestLogSink = sink
        policyLock.unlock()
    }

    public func registeredRouteSummaries() -> [WebRouteSummary] {
        lock.lock()
        defer { lock.unlock() }
        return routesByPlugin.flatMap { (pluginID, routes) in
            routes.map { route in
                WebRouteSummary(
                    pluginID: pluginID,
                    routeID: route.id,
                    method: route.method.rawValue,
                    path: route.path,
                    description: route.description
                )
            }
        }
    }

    // MARK: WebServerProviding - Lifecycle

    private func withLifecycleLock<T>(_ body: () -> T) -> T {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }
        return body()
    }

    public func start() async throws {
        let registration: (task: Task<Int, Error>, generation: Int)? = withLifecycleLock {
            guard lifecyclePhase == .idle else { return nil }
            lifecycleGeneration += 1
            let generation = lifecycleGeneration
            let task = Task { [self] in
                try await performStart()
            }
            startupTask = task
            lifecyclePhase = .starting
            return (task, generation)
        }
        guard let registration else { return }
        let startup = registration.task

        do {
            let actualPort = try await startup.value

            // 启动期间已被 stop 接管时不再标记为运行中：由 stop 负责关闭服务组。
            withLifecycleLock {
                // 已被 stop 关闭、或被后续 start 取代时，不能再修改运行状态。
                guard lifecyclePhase == .starting,
                      lifecycleGeneration == registration.generation else { return }
                lifecyclePhase = .running
                startupTask = nil
                boundPort = actualPort
                startedAt = Date()
                isRunning = true
            }
        } catch {
            let waitTask: Task<Void, Never>? = withLifecycleLock {
                // 本次启动已被后续生命周期操作取代，关闭工作由取代者负责。
                guard lifecycleGeneration == registration.generation else { return nil }
                if lifecyclePhase == .stopping { return shutdownTask }
                // 保持 stopping 直到 shutdown 完成，阻止新的 start 与旧服务组重叠。
                lifecyclePhase = .stopping
                let task = Task<Void, Never> { [weak self] in
                    _ = await self?.shutdown()
                }
                shutdownTask = task
                return task
            }
            await waitTask?.value
            throw error
        }
    }

    private func performStart() async throws -> Int {
        if startupDelayForTesting > .zero {
            try? await Task.sleep(for: startupDelayForTesting)
        }

        let gate = StartGate()
        let router = Router()
        router.middlewares.add(RouteDispatchMiddleware(server: self))

        let app = Application(
            responder: router.buildResponder(),
            configuration: .init(address: .hostname(listenHost, port: port)),
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

        // 等待服务真正绑定端口;若启动期间出错(如端口被占用)则抛出。
        return try await withCheckedThrowingContinuation { continuation in
            gate.arm(continuation)
        }
    }

    public func stop() async {
        let waitTask: Task<Void, Never>? = withLifecycleLock {
            switch lifecyclePhase {
            case .idle:
                return nil
            case .stopping:
                if let existing = shutdownTask { return existing }
                // 异常状态兜底：仍等待启动结束后关闭，避免遗留监听器。
                let startup = startupTask
                let task = Task { [weak self] in
                    _ = try? await startup?.value
                    await self?.shutdown()
                }
                shutdownTask = task
                return task
            case .starting, .running:
                lifecyclePhase = .stopping
                let startup = startupTask
                let task = Task { [weak self] in
                    _ = try? await startup?.value
                    await self?.shutdown()
                }
                shutdownTask = task
                return task
            }
        }
        await waitTask?.value
    }

    /// 关闭服务组并复位状态；调用方负责把 phase 置为 `.stopping` 或确保没有并发 start。
    private func shutdown() async {
        let resources: (ServiceGroup?, Task<Void, Never>?) = withLifecycleLock {
            isRunning = false
            let group = serviceGroup
            let runTask = self.runTask
            serviceGroup = nil
            self.runTask = nil
            return (group, runTask)
        }

        if let group = resources.0 {
            await group.triggerGracefulShutdown()
            _ = await resources.1?.value
        }

        withLifecycleLock {
            boundPort = nil
            startedAt = nil
            if lifecyclePhase == .stopping {
                lifecyclePhase = .idle
            }
            startupTask = nil
            shutdownTask = nil
        }
    }

    // MARK: Request Dispatch

    /// 处理一个 HTTP 请求:校验鉴权 → 匹配路由 → 在主线程执行 handler → 返回响应。
    func dispatch(request: Request) async throws -> Response {
        let startedAt = Date()
        let requestID = Self.resolveRequestID(from: request)
        let path = request.uri.path

        // 收集请求头(小写归一),鉴权与 CORS 都要用。
        var headers: [String: String] = [:]
        for field in request.headers {
            headers[field.name.description.lowercased()] = field.value
        }

        // 方法(HTTPTypes.Method -> 内核 HTTPMethod)
        guard let method = HTTPMethod(rawValue: request.method.rawValue) else {
            return finish(
                response: Self.makeErrorResponse(
                    error: .methodNotAllowed(),
                    requestID: requestID
                ),
                requestID: requestID,
                method: request.method.rawValue,
                path: path,
                pluginID: nil,
                startedAt: startedAt,
                headers: headers
            )
        }

        // CORS 预检:OPTIONS 请求直接应答,不进入路由匹配。
        if method == .options, let corsPolicy {
            let response = Self.makeCORSPreflightResponse(policy: corsPolicy)
            return finish(
                response: response,
                requestID: requestID,
                method: method.rawValue,
                path: path,
                pluginID: nil,
                startedAt: startedAt,
                headers: headers
            )
        }

        // 鉴权:未通过直接 401,不进入路由匹配(避免用 404 掩盖鉴权失败)。
        if let authError = authPolicy.validate(headers: headers) {
            return finish(
                response: Self.makeErrorResponse(error: authError, requestID: requestID),
                requestID: requestID,
                method: method.rawValue,
                path: path,
                pluginID: nil,
                startedAt: startedAt,
                headers: headers
            )
        }

        // CSRF 防护:跨源简单请求(CORS 预检之外的表单 POST)同样会送达，
        // 仅靠「不返回 CORS 响应头」无法阻止写操作，必须在执行前拒绝。
        if let rejection = crossOriginWriteRejection(method: method, headers: headers) {
            return finish(
                response: Self.makeErrorResponse(
                    error: .forbidden(message: rejection),
                    requestID: requestID
                ),
                requestID: requestID,
                method: method.rawValue,
                path: path,
                pluginID: nil,
                startedAt: startedAt,
                headers: headers
            )
        }

        // 内置自描述端点:GET /api/plugins,实时列出所有已注册路由(无需读取请求体)。
        if method == .get, path == Self.discoveryPath {
            let infos = discoveryRouteInfos()
            let webResponse = try WebRouteResponse.json(DiscoveryResponse(routes: infos))
            return finish(
                response: Self.makeResponse(from: webResponse, requestID: requestID),
                requestID: requestID,
                method: method.rawValue,
                path: path,
                pluginID: nil,
                startedAt: startedAt,
                headers: headers
            )
        }

        // 请求体
        var collated = request
        let buffer: ByteBuffer
        do {
            buffer = try await collated.collectBody(upTo: maxBodySize)
        } catch {
            return finish(
                response: Self.makeErrorResponse(
                    error: .payloadTooLarge(),
                    requestID: requestID
                ),
                requestID: requestID,
                method: method.rawValue,
                path: path,
                pluginID: nil,
                startedAt: startedAt,
                headers: headers
            )
        }
        var bodyData = Data()
        bodyData.append(contentsOf: buffer.readableBytesView)

        // 路由匹配
        guard let matched = matchRoute(method: method, path: path) else {
            // 路径存在但方法不匹配时返回 405,而非 404。
            let error: WebAPIError = hasPathMatch(path: path)
                ? .methodNotAllowed()
                : .notFound()
            return finish(
                response: Self.makeErrorResponse(error: error, requestID: requestID),
                requestID: requestID,
                method: method.rawValue,
                path: path,
                pluginID: nil,
                startedAt: startedAt,
                headers: headers
            )
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
        } catch let apiError as WebAPIError {
            return finish(
                response: Self.makeErrorResponse(error: apiError, requestID: requestID),
                requestID: requestID,
                method: method.rawValue,
                path: path,
                pluginID: matched.pluginID,
                startedAt: startedAt,
                headers: headers
            )
        } catch {
            // 未识别错误一律按 500 处理,且不回显内部细节——避免把实现细节
            // (文件路径、栈信息)泄露给外部调用方。完整信息留在服务端日志里。
            Self.logger.error(
                "\(Self.t)route handler failed: \(error.localizedDescription, privacy: .public)"
            )
            return finish(
                response: Self.makeErrorResponse(error: .internalError(), requestID: requestID),
                requestID: requestID,
                method: method.rawValue,
                path: path,
                pluginID: matched.pluginID,
                startedAt: startedAt,
                headers: headers
            )
        }

        let response = Self.makeResponse(from: result, requestID: requestID)

        // 发射活动记录(供宿主做 toast 反馈)。回调在网络线程触发,宿主需自行切线程。
        onActivity?(WebRequestActivity(
            pluginID: matched.pluginID,
            method: method.rawValue,
            path: path,
            description: matched.route.description,
            statusCode: result.statusCode
        ))

        return finish(
            response: response,
            requestID: requestID,
            method: method.rawValue,
            path: path,
            pluginID: matched.pluginID,
            startedAt: startedAt,
            headers: headers
        )
    }

    // MARK: - Helpers

    /// 统一的响应收尾:补 CORS 头、写请求日志。
    private func finish(
        response: Response,
        requestID: String,
        method: String,
        path: String,
        pluginID: String?,
        startedAt: Date,
        headers: [String: String]
    ) -> Response {
        var response = response
        if let corsPolicy {
            Self.applyCORSHeaders(to: &response, policy: corsPolicy, requestHeaders: headers)
        }

        let duration = Date().timeIntervalSince(startedAt)
        requestLogSink?.record(
            WebRequestLog(
                requestID: requestID,
                method: method,
                path: path,
                pluginID: pluginID,
                statusCode: Int(response.status.code),
                duration: duration
            )
        )
        return response
    }

    /// 会修改服务端状态的方法。
    private static func isStateChanging(_ method: HTTPMethod) -> Bool {
        switch method {
        case .post, .put, .patch, .delete: return true
        case .get, .head, .options: return false
        }
    }

    /// 拒绝浏览器发起的跨源写请求（CSRF）。
    ///
    /// 跨源表单 POST 属于「简单请求」，浏览器不会先发 CORS 预检，因此
    /// 「不返回 CORS 响应头」只能阻止页面读取响应，不能阻止写操作送达。
    /// 判定规则：
    /// - 显式配置的 CORS 允许来源视为已授权，放行其写请求；
    /// - `Sec-Fetch-Site` 为 `cross-site` / `same-site` 时拒绝；
    /// - `Origin` 与请求自身 host 不一致时拒绝；
    /// - 没有 `Origin` 的调用方不是浏览器页面（curl、原生客户端），保持兼容。
    ///
    /// - Returns: 拒绝文案；允许时返回 `nil`。
    private func crossOriginWriteRejection(method: HTTPMethod, headers: [String: String]) -> String? {
        guard Self.isStateChanging(method) else { return nil }

        let origin = headers["origin"]?.trimmingCharacters(in: .whitespaces)
        if let origin, !origin.isEmpty, corsPolicy?.allowedOrigin(in: origin) != nil {
            return nil
        }

        if let fetchSite = headers["sec-fetch-site"]?.trimmingCharacters(in: .whitespaces).lowercased(),
           fetchSite != "same-origin", fetchSite != "none" {
            return "Cross-origin \(method.rawValue) requests are not allowed."
        }

        guard let origin, !origin.isEmpty else { return nil }
        guard Self.isSameOrigin(origin, hostHeader: headers["host"], defaultPort: boundPort ?? port) else {
            return "Cross-origin \(method.rawValue) requests are not allowed."
        }
        return nil
    }

    /// `Origin` 是否与请求自身的 host 一致。
    private static func isSameOrigin(_ origin: String, hostHeader: String?, defaultPort: Int) -> Bool {
        guard let originComponents = URLComponents(string: origin),
              let scheme = originComponents.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let originHost = originComponents.host?.lowercased() else {
            return false
        }
        let originPort = originComponents.port ?? (scheme == "https" ? 443 : 80)

        let hostValue = (hostHeader?.isEmpty == false ? hostHeader : nil) ?? "127.0.0.1:\(defaultPort)"
        guard let hostComponents = URLComponents(string: "http://\(hostValue)"),
              let serverHost = hostComponents.host?.lowercased() else {
            return false
        }
        let serverPort = hostComponents.port ?? defaultPort
        return originHost == serverHost && originPort == serverPort
    }

    /// 解析或生成请求 ID。
    ///
    /// 优先透传调用方提供的 `X-Request-ID`,让外部系统能把自己的追踪 ID
    /// 贯穿到 Lumi 的日志里;缺失时生成一个。
    static func resolveRequestID(from request: Request) -> String {
        if let provided = request.headers[Self.requestIDHeader], !provided.isEmpty {
            return provided
        }
        return UUID().uuidString
    }

    private func matchRoute(method: HTTPMethod, path: String) -> (route: WebRoute, parameters: [String: String], pluginID: String)? {
        let snapshot: [(route: WebRoute, matcher: RouteMatcher, pluginID: String)] = {
            lock.lock(); defer { lock.unlock() }
            return matchers
        }()
        for entry in snapshot {
            guard entry.route.method == method else { continue }
            if let parameters = entry.matcher.match(path) {
                return (route: entry.route, parameters: parameters, pluginID: entry.pluginID)
            }
        }
        return nil
    }

    /// 是否存在路径匹配(不论方法)的路由。用于区分 404 与 405。
    private func hasPathMatch(path: String) -> Bool {
        let snapshot: [(route: WebRoute, matcher: RouteMatcher, pluginID: String)] = {
            lock.lock(); defer { lock.unlock() }
            return matchers
        }()
        return snapshot.contains { entry in
            entry.matcher.match(path) != nil
        }
    }

    /// 枚举当前所有已注册路由,供自描述端点 `GET /api/plugins` 返回。
    private func discoveryRouteInfos() -> [DiscoveryResponse.RouteInfo] {
        lock.lock(); defer { lock.unlock() }
        return routesByPlugin.flatMap { (pluginID, routes) in
            routes.map { route in
                DiscoveryResponse.RouteInfo(
                    plugin: pluginID,
                    id: route.id,
                    method: route.method.rawValue,
                    path: route.path,
                    description: route.description
                )
            }
        }
    }

    static func parseQuery(_ query: String?) -> [String: String] {
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

    private static func makeResponse(from webResponse: WebRouteResponse, requestID: String? = nil) -> Response {
        let buffer = ByteBuffer(bytes: webResponse.body)
        var response = Response(
            status: HTTPResponse.Status(code: webResponse.statusCode),
            body: ResponseBody(byteBuffer: buffer)
        )
        for (name, value) in webResponse.headers {
            if let fieldName = HTTPField.Name(name) {
                response.headers[fieldName] = value
            }
        }
        if let requestID {
            response.headers[Self.requestIDHeader] = requestID
        }
        return response
    }

    /// 构造统一格式的 JSON 错误响应。
    private static func makeErrorResponse(error: WebAPIError, requestID: String) -> Response {
        let body: Data
        do {
            body = try JSONEncoder().encode(WebErrorResponse(error, requestID: requestID))
        } catch {
            // 编码失败只可能是编码器本身的问题;退化为固定 JSON。
            body = Data("{\"error\":{\"code\":\"internal_error\",\"message\":\"Internal server error\"}}".utf8)
        }
        let buffer = ByteBuffer(bytes: body)
        var response = Response(
            status: HTTPResponse.Status(code: error.statusCode),
            body: ResponseBody(byteBuffer: buffer)
        )
        response.headers[.contentType] = "application/json"
        response.headers[Self.requestIDHeader] = requestID
        return response
    }

    /// 构造 CORS 预检响应。
    private static func makeCORSPreflightResponse(policy: WebCORSPolicy) -> Response {
        let buffer = ByteBufferAllocator().buffer(capacity: 0)
        var response = Response(
            status: .noContent,
            body: ResponseBody(byteBuffer: buffer)
        )
        applyCORSHeaders(to: &response, policy: policy, requestHeaders: [:])
        return response
    }

    /// 把 CORS 响应头写入响应。
    private static func applyCORSHeaders(
        to response: inout Response,
        policy: WebCORSPolicy,
        requestHeaders: [String: String]
    ) {
        guard let origin = policy.allowedOrigin(in: requestHeaders["origin"]) else { return }
        response.headers[Self.allowOriginHeader] = origin
        response.headers[Self.allowMethodsHeader] = policy.allowedMethods.joined(separator: ", ")
        response.headers[Self.allowHeadersHeader] = policy.allowedHeaders.joined(separator: ", ")
        if policy.allowsCredentials {
            response.headers[Self.allowCredentialsHeader] = "true"
        }
        if let maxAge = policy.maxAge {
            response.headers[Self.maxAgeHeader] = String(maxAge)
        }
    }
}
