import Foundation
import ProviderPluginManaging
import ProviderWebServer

// MARK: - Route Contribution Host

/// 插件路由贡献的宿主。
///
/// 负责把插件声明的路由下发到 Web 服务，并在插件启停时同步上下线。
///
/// ## 生命周期
///
/// 1. 插件在 `onBoot` 中通过 `contribute(...)` 登记自己的路由。
/// 2. 宿主在所有插件启动完成后（`onReady`）把路由下发到服务。
/// 3. 插件被禁用时，其路由自动下线；被重新启用时自动恢复。
///
/// 这样插件不必关心「什么时候服务已经能接请求」——登记与下发是两件事，
/// 避免插件在 `onBoot` 阶段与服务产生启动顺序耦合。
@MainActor
public final class WebRouteContributionHost {
    /// 目标 Web 服务。
    private weak var server: (any WebServerProviding)?

    /// 插件管理与观察者。
    private weak var pluginManager: (any PluginManaging)?

    /// 已登记的贡献：插件 ID -> 路由。
    private var routesByPlugin: [String: [WebRoute]] = [:]

    /// 已下发的插件 ID 集合（区分「已登记」与「已生效」）。
    private var activePluginIDs: Set<String> = []

    /// 插件观察句柄。
    private var pluginObserver: (any PluginManagingObserverHandle)?

    /// 是否已把登记的贡献下发到服务。
    private var isPublished = false

    /// 创建贡献宿主。
    ///
    /// - Parameters:
    ///   - server: 目标 Web 服务。
    ///   - pluginManager: 插件管理器，用于观察启停事件。
    public init(
        server: any WebServerProviding,
        pluginManager: (any PluginManaging)? = nil
    ) {
        self.server = server
        self.pluginManager = pluginManager
    }

    /// 开始观察插件启停。
    ///
    /// 插件被禁用时其路由下线；被重新启用时其路由恢复。
    public func startObserving() {
        guard pluginObserver == nil, let pluginManager else { return }
        pluginObserver = pluginManager.addPluginObserver { [weak self] event in
            guard let self else { return }
            switch event {
            case .enabledStateChanged(let pluginID, let enabled):
                self.handleEnabledStateChanged(pluginID: pluginID, enabled: enabled)
            case .listChanged:
                self.syncAll()
            }
        }
    }

    /// 停止观察插件启停。
    public func stopObserving() {
        pluginObserver?.cancel()
        pluginObserver = nil
    }

    /// 登记一个插件的路由贡献。
    ///
    /// 幂等：同一 `pluginID` 再次登记会整体替换其旧路由。
    ///
    /// - Parameters:
    ///   - routes: 该插件贡献的全部路由。
    ///   - pluginID: 归属插件 ID。
    public func contribute(_ routes: [WebRoute], forPlugin pluginID: String) {
        routesByPlugin[pluginID] = routes
        // 已下发阶段才立即生效；否则等 `publish()` 统一下发。
        if isPublished {
            applyRoutes(for: pluginID)
        }
    }

    /// 注销一个插件的路由贡献。
    ///
    /// - Parameter pluginID: 归属插件 ID。
    public func revoke(pluginID: String) {
        routesByPlugin.removeValue(forKey: pluginID)
        if isPublished {
            server?.unregister(pluginID: pluginID)
            activePluginIDs.remove(pluginID)
        }
    }

    /// 把全部登记的贡献下发到服务。
    ///
    /// 只下发**当前已启用**插件的路由——被禁用的插件本就不该对外提供能力。
    public func publish() {
        isPublished = true
        syncAll()
    }

    /// 撤销全部已下发的路由。
    public func unpublishAll() {
        for pluginID in activePluginIDs {
            server?.unregister(pluginID: pluginID)
        }
        activePluginIDs.removeAll()
        isPublished = false
    }

    /// 已登记的插件数量。
    public var contributedPluginCount: Int {
        routesByPlugin.count
    }

    /// 当前生效的路由总数。
    public var activeRouteCount: Int {
        activePluginIDs.reduce(0) { total, pluginID in
            total + (routesByPlugin[pluginID]?.count ?? 0)
        }
    }

    // MARK: - Private

    /// 处理插件启停事件。
    private func handleEnabledStateChanged(pluginID: String, enabled: Bool) {
        guard isPublished else { return }
        if enabled {
            applyRoutes(for: pluginID)
        } else {
            server?.unregister(pluginID: pluginID)
            activePluginIDs.remove(pluginID)
        }
    }

    /// 按当前插件启用状态同步全部贡献。
    private func syncAll() {
        guard isPublished else { return }
        for pluginID in routesByPlugin.keys {
            if isPluginEnabled(pluginID) {
                applyRoutes(for: pluginID)
            } else {
                server?.unregister(pluginID: pluginID)
                activePluginIDs.remove(pluginID)
            }
        }
    }

    /// 插件当前是否处于启用状态。
    ///
    /// 拿不到插件管理器时**假定为启用**——无法判定状态不应成为阻断端点
    /// 上线的理由（宿主可能没有装配插件管理能力，只想要一个纯 HTTP 服务）。
    private func isPluginEnabled(_ pluginID: String) -> Bool {
        guard let pluginManager else { return true }
        return pluginManager.isEnabled(id: pluginID)
    }

    /// 把某个插件的路由下发到服务。
    private func applyRoutes(for pluginID: String) {
        guard let routes = routesByPlugin[pluginID], !routes.isEmpty else { return }
        server?.register(routes, forPlugin: pluginID)
        activePluginIDs.insert(pluginID)
    }
}
