import Foundation
import ProviderWebServer

// MARK: - Route Contribution Registry

/// 插件路由贡献的注册表。
///
/// 负责把「哪个插件贡献了哪些路由」这件事实集中管理，并保证：
/// - 同一插件重复注册时整体替换（幂等）
/// - 插件被禁用或卸载时其路由自动下线
/// - 路由按插件分组，便于自描述端点与诊断
///
/// 与 `WebServerProviding.register(_:forPlugin:)` 的区别：注册表只管
/// **贡献关系**，真正的路由下发由宿主在装配时完成。
public final class WebRouteContributionRegistry: @unchecked Sendable {
    private let lock = NSLock()
    /// 插件 ID -> 其贡献的路由。
    private var routesByPlugin: [String: [WebRoute]] = [:]
    /// 插件 ID -> 贡献标识。
    private var contributionIDs: [String: String] = [:]

    /// 创建注册表。
    public init() {}

    /// 注册（或替换）某个插件的路由贡献。
    ///
    /// 幂等：同一 `pluginID` 再次调用会整体替换其旧路由。
    ///
    /// - Parameters:
    ///   - routes: 该插件贡献的全部路由。
    ///   - pluginID: 归属插件 ID。
    ///   - contributionID: 贡献标识，默认等于插件 ID。
    public func register(
        _ routes: [WebRoute],
        forPlugin pluginID: String,
        contributionID: String? = nil
    ) {
        lock.lock()
        if routes.isEmpty {
            routesByPlugin.removeValue(forKey: pluginID)
            contributionIDs.removeValue(forKey: pluginID)
        } else {
            routesByPlugin[pluginID] = routes
            contributionIDs[pluginID] = contributionID ?? pluginID
        }
        lock.unlock()
    }

    /// 注销某个插件的全部路由。
    public func unregister(pluginID: String) {
        lock.lock()
        routesByPlugin.removeValue(forKey: pluginID)
        contributionIDs.removeValue(forKey: pluginID)
        lock.unlock()
    }

    /// 移除全部贡献。
    public func removeAll() {
        lock.lock()
        routesByPlugin.removeAll()
        contributionIDs.removeAll()
        lock.unlock()
    }

    /// 某插件当前贡献的路由。
    public func routes(forPlugin pluginID: String) -> [WebRoute] {
        lock.lock()
        defer { lock.unlock() }
        return routesByPlugin[pluginID] ?? []
    }

    /// 全部路由的快照（按插件分组展开）。
    public func snapshot() -> [(pluginID: String, routes: [WebRoute])] {
        lock.lock()
        defer { lock.unlock() }
        return routesByPlugin.map { (pluginID: $0.key, routes: $0.value) }
    }

    /// 已贡献路由的插件数量。
    public var pluginCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return routesByPlugin.count
    }

    /// 全部路由的总数。
    public var routeCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return routesByPlugin.values.reduce(0) { $0 + $1.count }
    }

    /// 路由摘要列表，供自描述端点使用。
    public func summaries() -> [WebRouteSummary] {
        snapshot().flatMap { entry in
            entry.routes.map { route in
                WebRouteSummary(
                    pluginID: entry.pluginID,
                    routeID: route.id,
                    method: route.method.rawValue,
                    path: route.path,
                    description: route.description
                )
            }
        }
    }
}
