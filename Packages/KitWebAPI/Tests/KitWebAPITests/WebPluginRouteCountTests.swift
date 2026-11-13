import Foundation
import KernelCore
import ProviderPluginManaging
import ProviderWebServer
import Testing
@testable import KitWebAPI

// MARK: - Test Doubles

/// 测试用桩插件：只提供身份与元数据，不执行任何生命周期行为。
@MainActor
private final class StubPlugin: SuperPlugin {
    let id: String
    let metadata: PluginMetadata

    init(id: String) {
        self.id = id
        self.metadata = PluginMetadata(id: id)
    }
}

/// 可变的每插件路由数来源，用于验证实时求值。
@MainActor
private final class RouteCountSource {
    var counts: [String: Int] = ["plugin.alpha": 2]
}

// MARK: - Plugin Route Count Tests

@MainActor
@Suite("WebPluginRouteCount")
struct WebPluginRouteCountTests {
    /// 内核容器。DefaultPluginManager 只弱引用内核，
    /// 必须由测试持有强引用，否则注册表随容器释放而清空。
    private let kernel = KernelCoreContainer()

    /// 构造带真实插件管理器的控制面上下文（内核注册两个桩插件）。
    private func makeContext() throws -> WebControlContext {
        try kernel.registerPlugin(StubPlugin(id: "plugin.alpha"))
        try kernel.registerPlugin(StubPlugin(id: "plugin.beta"))
        return WebControlContext(pluginManager: DefaultPluginManager(kernel: kernel))
    }

    /// 构造控制面路由。
    private func makeRoutes(
        context: WebControlContext,
        routeCounts: @escaping @MainActor @Sendable () -> [String: Int] = { [:] }
    ) -> [WebRoute] {
        WebControlRoutes.makeRoutes(context: context, routeCounts: routeCounts) {
            WebStatusResponse.Service(
                version: "v1",
                uptime: 0,
                routeCount: 0,
                authenticationEnabled: false,
                host: "127.0.0.1",
                port: 7310
            )
        }
    }

    /// 请求插件列表并解码出 id → routeCount 映射。
    private func fetchRouteCounts(routes: [WebRoute]) async throws -> [String: Int] {
        let route = try #require(routes.first { $0.path == "/api/v1/plugins" && $0.method == .get })
        let response = try await route.handler(WebRouteRequest(method: .get, path: "/api/v1/plugins"))
        #expect(response.statusCode == 200)

        struct Envelope: Decodable {
            struct Item: Decodable {
                let id: String
                let routeCount: Int
            }
            let data: [Item]
        }
        let decoded = try JSONDecoder().decode(Envelope.self, from: response.body)
        return Dictionary(uniqueKeysWithValues: decoded.data.map { ($0.id, $0.routeCount) })
    }

    @Test("插件列表按插件 id 报告真实路由数量")
    func reportsRouteCountsPerPlugin() async throws {
        let context = try makeContext()
        let routes = makeRoutes(context: context) {
            ["plugin.alpha": 3, "plugin.beta": 1]
        }

        let counts = try await fetchRouteCounts(routes: routes)
        #expect(counts["plugin.alpha"] == 3)
        #expect(counts["plugin.beta"] == 1)
    }

    @Test("未提供路由数来源时全部插件计 0")
    func defaultsToZeroWithoutSource() async throws {
        let context = try makeContext()
        let routes = makeRoutes(context: context)

        let counts = try await fetchRouteCounts(routes: routes)
        #expect(counts["plugin.alpha"] == 0)
        #expect(counts["plugin.beta"] == 0)
    }

    @Test("未出现在路由数表中的插件计 0")
    func unlistedPluginCountsZero() async throws {
        let context = try makeContext()
        let routes = makeRoutes(context: context) { ["plugin.alpha": 7] }

        let counts = try await fetchRouteCounts(routes: routes)
        #expect(counts["plugin.alpha"] == 7)
        #expect(counts["plugin.beta"] == 0)
    }

    @Test("路由数按请求实时求值，注册变化后无需重建路由")
    func routeCountsRefreshPerRequest() async throws {
        let context = try makeContext()
        let source = RouteCountSource()
        let routes = makeRoutes(context: context) { source.counts }

        let first = try await fetchRouteCounts(routes: routes)
        #expect(first["plugin.alpha"] == 2)

        source.counts = ["plugin.alpha": 5]
        let second = try await fetchRouteCounts(routes: routes)
        #expect(second["plugin.alpha"] == 5)
    }
}