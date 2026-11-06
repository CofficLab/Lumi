import Foundation
import ProviderWebServer

// MARK: - Route Contribution Registrar

/// 插件侧的路由贡献登记器。
///
/// 插件在 `onBoot` 中拿到它，把自己的端点登记进来即可——**一行代码**完成
/// 「把自己的能力暴露为 HTTP 端点」：
///
/// ```swift
/// let registrar = WebRouteRegistrar(pluginID: id)
/// registrar.contribute {
///     WebRouteBuilder(prefix: "my-plugin")
///         .get("/api/v1/my-plugin/state") { _ in
///             try .api(["ready": true])
///         }
///         .build()
/// }
/// ```
///
/// 登记与下发是两件事：登记只记录「这个插件有哪些端点」，真正下发到服务
/// 由宿主在插件全部启动后统一完成。这样插件不必关心服务何时就绪。
@MainActor
public final class WebRouteRegistrar {
    /// 归属插件 ID。
    public let pluginID: String

    /// 已登记的路由。
    private var routes: [WebRoute] = []

    /// 创建登记器。
    ///
    /// - Parameter pluginID: 归属插件 ID。
    public init(pluginID: String) {
        self.pluginID = pluginID
    }

    /// 登记一组路由（替换之前登记的全部路由）。
    ///
    /// - Parameter routes: 该插件贡献的全部路由。
    public func contribute(_ routes: [WebRoute]) {
        self.routes = routes
    }

    /// 登记一组路由（替换之前登记的全部路由）。
    ///
    /// - Parameter builder: 返回路由列表的闭包。
    public func contribute(_ builder: () -> [WebRoute]) {
        contribute(builder())
    }

    /// 撤销全部登记。
    public func revoke() {
        routes.removeAll()
    }

    /// 当前登记的路由。
    public var registeredRoutes: [WebRoute] {
        routes
    }
}

// MARK: - Contribution Registry (Plugin-side)

/// 插件路由贡献的登记表。
///
/// 宿主用它汇总所有插件的贡献，再统一下发到 Web 服务。
@MainActor
public final class WebRouteContributionTable {
    /// 插件 ID -> 登记器。
    private var registrars: [String: WebRouteRegistrar] = [:]

    /// 创建登记表。
    public init() {}

    /// 为某个插件创建（或取回）登记器。
    ///
    /// - Parameter pluginID: 归属插件 ID。
    /// - Returns: 登记器。
    public func registrar(for pluginID: String) -> WebRouteRegistrar {
        if let existing = registrars[pluginID] {
            return existing
        }
        let registrar = WebRouteRegistrar(pluginID: pluginID)
        registrars[pluginID] = registrar
        return registrar
    }

    /// 移除某个插件的登记。
    public func remove(pluginID: String) {
        registrars.removeValue(forKey: pluginID)
    }

    /// 全部登记的路由（按插件分组展开）。
    public func snapshot() -> [(pluginID: String, routes: [WebRoute])] {
        registrars.compactMap { pluginID, registrar in
            let routes = registrar.registeredRoutes
            return routes.isEmpty ? nil : (pluginID: pluginID, routes: routes)
        }
    }

    /// 已登记的插件数量。
    public var pluginCount: Int {
        registrars.values.filter { !$0.registeredRoutes.isEmpty }.count
    }

    /// 全部登记的路由总数。
    public var routeCount: Int {
        registrars.values.reduce(0) { $0 + $1.registeredRoutes.count }
    }
}
