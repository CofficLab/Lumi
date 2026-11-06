import Foundation

// MARK: - Extended Web Server Capability

/// 扩展的 Web 服务能力协议。
///
/// 在基础的「注册路由 + 启停」之上，提供：
/// - 鉴权策略（统一在派发前校验，插件处理器无需各自实现）
/// - 请求日志（统一记录元信息，供设置页与诊断使用）
/// - 版本化路径前缀（核心控制面端点的统一命名空间）
///
/// 基础协议 `WebServerProviding` 的实现可以只实现基础部分；宿主在需要
/// 鉴权/日志时使用本协议。未实现本协议时，服务以「无鉴权、无日志」运行，
/// 与既有行为一致。
public protocol WebServerExtendedProviding: WebServerProviding {
    /// 当前生效的鉴权策略。
    var authPolicy: WebAuthPolicy { get }

    /// 设置鉴权策略。
    ///
    /// - Parameter policy: 新的鉴权策略。
    func setAuthPolicy(_ policy: WebAuthPolicy)

    /// 请求日志接收端。
    var requestLogSink: (any WebRequestLogSink)? { get }

    /// 设置请求日志接收端。
    ///
    /// - Parameter sink: 日志接收端；传 `nil` 表示关闭日志。
    func setRequestLogSink(_ sink: (any WebRequestLogSink)?)

    /// 当前已注册的路由总数。
    var registeredRouteCount: Int { get }

    /// 枚举当前已注册的全部路由，供自描述端点返回。
    ///
    /// - Returns: 每个路由的归属插件、方法、路径与描述。
    func registeredRouteSummaries() -> [WebRouteSummary]
}

/// 路由的摘要信息（用于自描述端点）。
public struct WebRouteSummary: Sendable, Equatable, Codable {
    /// 归属插件 ID。
    public let pluginID: String
    /// 路由 id。
    public let routeID: String
    /// HTTP 方法。
    public let method: String
    /// 路由路径模板。
    public let path: String
    /// 人类可读描述。
    public let description: String?

    public init(
        pluginID: String,
        routeID: String,
        method: String,
        path: String,
        description: String? = nil
    ) {
        self.pluginID = pluginID
        self.routeID = routeID
        self.method = method
        self.path = path
        self.description = description
    }
}

// MARK: - Defaults

public extension WebServerExtendedProviding {
    func setAuthPolicy(_ policy: WebAuthPolicy) {}
    func setRequestLogSink(_ sink: (any WebRequestLogSink)?) {}
    var registeredRouteCount: Int { registeredRouteSummaries().count }
}

// MARK: - Route Registry

/// 线程安全的路由表。
///
/// 服务端在后台线程匹配路由、在主线程注册路由，两者并发发生，因此路由表
/// 必须自带锁保护。本类型把这套「按插件分组 + 幂等替换 + 快照匹配」的逻辑
/// 从具体服务实现里抽出来，宿主与默认实现共用同一套语义。
public final class WebRouteRegistry: @unchecked Sendable {
    private let lock = NSLock()
    private var routesByPlugin: [String: [WebRoute]] = [:]

    /// 创建路由表。
    public init() {}

    /// 注册(替换)指定插件贡献的一组路由。
    ///
    /// 同一 `pluginID` 再次调用会整体替换其旧路由(幂等替换)。传入空数组等效于
    /// 注销。
    public func register(_ routes: [WebRoute], forPlugin pluginID: String) {
        lock.lock()
        if routes.isEmpty {
            routesByPlugin.removeValue(forKey: pluginID)
        } else {
            routesByPlugin[pluginID] = routes
        }
        lock.unlock()
    }

    /// 注销指定插件的所有路由。
    public func unregister(pluginID: String) {
        lock.lock()
        routesByPlugin.removeValue(forKey: pluginID)
        lock.unlock()
    }

    /// 移除全部路由。
    public func removeAll() {
        lock.lock()
        routesByPlugin.removeAll()
        lock.unlock()
    }

    /// 已注册的路由总数。
    public var routeCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return routesByPlugin.values.reduce(0) { $0 + $1.count }
    }

    /// 归属插件 ID 列表（按注册顺序无关，仅用于诊断）。
    public var pluginIDs: [String] {
        lock.lock()
        defer { lock.unlock() }
        return Array(routesByPlugin.keys)
    }

    /// 全部路由的快照（按插件分组展开）。
    public func snapshot() -> [(pluginID: String, route: WebRoute)] {
        lock.lock()
        defer { lock.unlock() }
        return routesByPlugin.flatMap { pluginID, routes in
            routes.map { (pluginID: pluginID, route: $0) }
        }
    }

    /// 路由摘要列表，供自描述端点使用。
    public func summaries() -> [WebRouteSummary] {
        snapshot().map { entry in
            WebRouteSummary(
                pluginID: entry.pluginID,
                routeID: entry.route.id,
                method: entry.route.method.rawValue,
                path: entry.route.path,
                description: entry.route.description
            )
        }
    }
}
