import Foundation
import KernelCore
import KitAgentTool
import ProviderPluginControl
import ProviderPluginManaging
import ProviderSettingView
import ProviderTheme
import ProviderToolManager
import ProviderWebServer
import Testing
import KitWebAPI
import KitWebServer
@testable import PluginWebServer

// MARK: - Test Doubles

/// 记录路由注册/注销的假服务。
private final class RecordingWebServer: WebServerProviding, @unchecked Sendable {
    let port = 0
    var isRunning = false

    private let lock = NSLock()
    private var routesByPlugin: [String: [WebRoute]] = [:]
    private var registerLog: [String] = []
    private var unregisterLog: [String] = []

    func register(_ routes: [WebRoute], forPlugin pluginID: String) {
        lock.lock()
        routesByPlugin[pluginID] = routes
        registerLog.append(pluginID)
        lock.unlock()
    }

    func unregister(pluginID: String) {
        lock.lock()
        routesByPlugin.removeValue(forKey: pluginID)
        unregisterLog.append(pluginID)
        lock.unlock()
    }

    func start() async throws {}
    func stop() async {}

    var registeredPluginIDs: [String] {
        lock.lock()
        defer { lock.unlock() }
        return Array(routesByPlugin.keys)
    }

    var routeCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return routesByPlugin.values.reduce(0) { $0 + $1.count }
    }

    var registeredPlugins: [String] {
        lock.lock()
        defer { lock.unlock() }
        return registerLog
    }

    var unregisteredPlugins: [String] {
        lock.lock()
        defer { lock.unlock() }
        return unregisterLog
    }
}

/// 可控启停状态的假插件管理器。
@MainActor
private final class FakePluginManager: PluginManaging, PluginControlling {
    private(set) var enabledIDs: Set<String> = []
    private var observers: [UUID: (PluginManagingEvent) -> Void] = [:]
    var lastErrorDescription: String?

    func enablePlugin(id: String) async -> Bool {
        setEnabled(true, for: id)
        return true
    }

    func disablePlugin(id: String) async -> Bool {
        setEnabled(false, for: id)
        return true
    }

    func setEnabled(_ enabled: Bool, for pluginID: String) {
        if enabled {
            enabledIDs.insert(pluginID)
        } else {
            enabledIDs.remove(pluginID)
        }
        notify(.enabledStateChanged(pluginID: pluginID, enabled: enabled))
    }

    var allPlugins: [any SuperPlugin] { [] }
    var configurablePlugins: [any SuperPlugin] { [] }
    var pluginCount: Int { enabledIDs.count }
    var enabledCount: Int { enabledIDs.count }
    func plugin(id: String) -> (any SuperPlugin)? { nil }
    func isRegistered(id: String) -> Bool { true }
    func unloadPlugin(id: String) throws {}
    func reloadPlugin(id: String) throws {}
    func enabledPlugins(from candidates: [any SuperPlugin]) -> [any SuperPlugin] { candidates }
    func isEnabled(id: String) -> Bool { enabledIDs.contains(id) }

    @discardableResult
    func addPluginObserver(_ callback: @escaping (PluginManagingEvent) -> Void) -> any PluginManagingObserverHandle {
        let id = UUID()
        observers[id] = callback
        return FakeObserverHandle { [weak self] in
            self?.observers.removeValue(forKey: id)
        }
    }

    private func notify(_ event: PluginManagingEvent) {
        for callback in observers.values {
            callback(event)
        }
    }
}

/// 最小可用工具管理器：只满足工具桥接需要的注册表查询。
///
/// 生产环境里工具管理器与核心控制面同时存在，两者共用一次路由注册，
/// 测试必须复现这个组合才能发现彼此覆盖。
@MainActor
private final class StubToolManager: ToolManagerProviding {
    private var toolsByPlugin: [String: [any SuperAgentTool]] = [:]

    func allTools() -> [any SuperAgentTool] {
        toolsByPlugin.values.flatMap { $0 }
    }

    func add(_ tool: any SuperAgentTool, pluginID: String) {
        toolsByPlugin[pluginID, default: []].append(tool)
    }

    func remove(id: String) {
        for key in toolsByPlugin.keys {
            toolsByPlugin[key]?.removeAll { $0.name == id }
        }
    }

    func toolsGroupedByPlugin() -> [(pluginID: String, tools: [any SuperAgentTool])] {
        toolsByPlugin.map { ($0.key, $0.value) }
    }

    func tool(named name: String) -> (any SuperAgentTool)? {
        allTools().first { $0.name == name }
    }

    func displayDescription(for toolCall: ToolCall) -> String? {
        toolCall.name
    }

    func riskLevel(for toolCall: ToolCall) -> CommandRiskLevel? {
        .safe
    }

    func execute(
        _ toolCall: ToolCall,
        conversationID: UUID,
        turnID: UUID?
    ) async -> ToolCallResult {
        ToolCallResult(content: "")
    }

    func toolCalls(for turnID: UUID) async -> [ToolCallRecord] { [] }

    func toolCallResult(for toolCallID: String) async -> ToolCallResult? { nil }

    func deleteToolCalls(for conversationID: UUID) async {}
}

private final class FakeObserverHandle: PluginManagingObserverHandle {
    private let onCancel: () -> Void
    private var isCancelled = false

    init(onCancel: @escaping () -> Void) {
        self.onCancel = onCancel
    }

    func cancel() {
        guard !isCancelled else { return }
        isCancelled = true
        onCancel()
    }
}

// MARK: - Registrar Tests

@MainActor
@Suite("WebRouteRegistrar")
struct WebRouteRegistrarTests {
    @Test("登记端点后可读回")
    func registersRoutes() {
        let registrar = WebRouteRegistrar(pluginID: "com.test.plugin")
        registrar.contribute {
            WebRouteBuilder(prefix: "test")
                .get("/api/v1/test/ping") { _ in .text("pong") }
                .build()
        }

        #expect(registrar.registeredRoutes.count == 1)
        #expect(registrar.registeredRoutes.first?.path == "/api/v1/test/ping")
    }

    @Test("重复登记整体替换旧端点")
    func replacesOnSecondRegistration() {
        let registrar = WebRouteRegistrar(pluginID: "com.test.plugin")
        registrar.contribute { [WebRoute(id: "a", method: .get, path: "/a") { _ in .text("a") }] }
        registrar.contribute { [WebRoute(id: "b", method: .get, path: "/b") { _ in .text("b") }] }

        #expect(registrar.registeredRoutes.count == 1)
        #expect(registrar.registeredRoutes.first?.id == "b")
    }

    @Test("撤销后端点清空")
    func revokesRoutes() {
        let registrar = WebRouteRegistrar(pluginID: "com.test.plugin")
        registrar.contribute { [WebRoute(id: "a", method: .get, path: "/a") { _ in .text("a") }] }
        registrar.revoke()

        #expect(registrar.registeredRoutes.isEmpty)
    }

    @Test("登记表按插件分组聚合")
    func aggregatesByPlugin() {
        let table = WebRouteContributionTable()
        table.registrar(for: "plugin.a").contribute { [WebRoute(id: "a", method: .get, path: "/a") { _ in .text("a") }] }
        table.registrar(for: "plugin.b").contribute { [WebRoute(id: "b", method: .get, path: "/b") { _ in .text("b") }] }

        #expect(table.pluginCount == 2)
        #expect(table.routeCount == 2)
        #expect(table.snapshot().count == 2)
    }
}

// MARK: - Contribution Host Tests

@MainActor
@Suite("WebRouteContributionHost")
struct WebRouteContributionHostTests {
    @Test("发布后端点下发到服务")
    func publishesRoutes() {
        let server = RecordingWebServer()
        let manager = FakePluginManager()
        manager.setEnabled(true, for: "plugin.a")

        let host = WebRouteContributionHost(server: server, pluginManager: manager)
        host.contribute(
            [WebRoute(id: "a", method: .get, path: "/a") { _ in .text("a") }],
            forPlugin: "plugin.a"
        )
        host.publish()

        #expect(server.routeCount == 1)
        #expect(server.registeredPluginIDs == ["plugin.a"])
        #expect(host.activeRouteCount == 1)
    }

    @Test("被禁用的插件其端点不下发")
    func skipsDisabledPlugins() {
        let server = RecordingWebServer()
        let manager = FakePluginManager()
        // 插件默认未启用。

        let host = WebRouteContributionHost(server: server, pluginManager: manager)
        host.contribute(
            [WebRoute(id: "a", method: .get, path: "/a") { _ in .text("a") }],
            forPlugin: "plugin.a"
        )
        host.publish()

        #expect(server.routeCount == 0)
    }

    @Test("插件启用后其端点自动上线")
    func routesComeOnlineOnEnable() {
        let server = RecordingWebServer()
        let manager = FakePluginManager()
        let host = WebRouteContributionHost(server: server, pluginManager: manager)
        host.contribute(
            [WebRoute(id: "a", method: .get, path: "/a") { _ in .text("a") }],
            forPlugin: "plugin.a"
        )
        host.publish()
        host.startObserving()

        #expect(server.routeCount == 0)

        manager.setEnabled(true, for: "plugin.a")

        #expect(server.routeCount == 1)
        #expect(server.registeredPluginIDs == ["plugin.a"])
    }

    @Test("插件禁用后其端点自动下线")
    func routesGoOfflineOnDisable() {
        let server = RecordingWebServer()
        let manager = FakePluginManager()
        manager.setEnabled(true, for: "plugin.a")

        let host = WebRouteContributionHost(server: server, pluginManager: manager)
        host.contribute(
            [WebRoute(id: "a", method: .get, path: "/a") { _ in .text("a") }],
            forPlugin: "plugin.a"
        )
        host.publish()
        host.startObserving()

        #expect(server.routeCount == 1)

        manager.setEnabled(false, for: "plugin.a")

        #expect(server.routeCount == 0)
        #expect(server.unregisteredPlugins.contains("plugin.a"))
    }

    @Test("撤销贡献后端点下线")
    func revokesContribution() {
        let server = RecordingWebServer()
        let manager = FakePluginManager()
        manager.setEnabled(true, for: "plugin.a")

        let host = WebRouteContributionHost(server: server, pluginManager: manager)
        host.contribute(
            [WebRoute(id: "a", method: .get, path: "/a") { _ in .text("a") }],
            forPlugin: "plugin.a"
        )
        host.publish()

        #expect(server.routeCount == 1)

        host.revoke(pluginID: "plugin.a")

        #expect(server.routeCount == 0)
    }

    @Test("停止观察后不再响应启停事件")
    func stopsObserving() {
        let server = RecordingWebServer()
        let manager = FakePluginManager()
        let host = WebRouteContributionHost(server: server, pluginManager: manager)
        host.contribute(
            [WebRoute(id: "a", method: .get, path: "/a") { _ in .text("a") }],
            forPlugin: "plugin.a"
        )
        host.publish()
        host.startObserving()
        host.stopObserving()

        manager.setEnabled(true, for: "plugin.a")

        #expect(server.routeCount == 0)
    }

    @Test("取消全部发布后服务上无残留路由")
    func unpublishesAll() {
        let server = RecordingWebServer()
        let manager = FakePluginManager()
        manager.setEnabled(true, for: "plugin.a")

        let host = WebRouteContributionHost(server: server, pluginManager: manager)
        host.contribute(
            [WebRoute(id: "a", method: .get, path: "/a") { _ in .text("a") }],
            forPlugin: "plugin.a"
        )
        host.publish()

        #expect(server.routeCount == 1)

        host.unpublishAll()

        #expect(server.routeCount == 0)
    }
}

// MARK: - Plugin Integration Tests

@MainActor
@Suite("PluginWebServer 路由贡献")
struct WebServerPluginContributionTests {
    @Test("插件可声明式贡献端点并在 ready 后下发")
    func contributesRoutesOnReady() throws {
        let kernel = KernelCoreContainer()
        let theme = DefaultThemeProviding()
        try kernel.registerProvider((any ThemeProviding).self, theme)
        try kernel.registerProvider((any WebServerProviding).self, DefaultWebServerProviding())
        try kernel.registerProvider(
            (any SettingViewProviding).self,
            DefaultSettingViewProviding()
        )

        let plugin = WebServerPlugin()
        try plugin.onBoot(kernel: kernel)

        let server = try #require(kernel.resolveProvider((any WebServerProviding).self))
        let webServer = try #require(server as? LumiWebServer)

        // 核心控制面路由由宿主直接注册，boot 后即可用。
        let bootSummaries = webServer.registeredRouteSummaries()
        #expect(bootSummaries.contains { $0.path == "/api/v1/status" })

        // 主题端点走「声明式贡献」：登记后尚未下发，ready 时才生效。
        #expect(!bootSummaries.contains { $0.path == "/api/plugins/theme-manager/themes" })

        try plugin.onReady(kernel: kernel)

        let summaries = webServer.registeredRouteSummaries()
        #expect(summaries.contains { $0.path == "/api/plugins/theme-manager/themes" })
        #expect(summaries.contains { $0.path == "/api/plugins/theme-manager/themes/:id/select" })
    }

    @Test("核心控制面与工具桥接的路由同时生效")
    func keepsCoreAndToolRoutesTogether() throws {
        let kernel = KernelCoreContainer()
        try kernel.registerProvider((any ThemeProviding).self, DefaultThemeProviding())
        try kernel.registerProvider((any WebServerProviding).self, DefaultWebServerProviding())
        try kernel.registerProvider(
            (any SettingViewProviding).self,
            DefaultSettingViewProviding()
        )
        // 生产环境始终注册了工具管理器，工具桥接路由因此也会参与注册。
        try kernel.registerProvider(
            (any ToolManagerProviding).self,
            StubToolManager()
        )

        let plugin = WebServerPlugin()
        try plugin.onBoot(kernel: kernel)

        let server = try #require(
            kernel.resolveProvider((any WebServerProviding).self) as? LumiWebServer
        )
        let paths = Set(server.registeredRouteSummaries().map(\.path))

        // 同一插件分两次注册会整体替换，导致前一组路由全部 404。
        #expect(paths.contains("/api/v1/status"))
        #expect(paths.contains("/api/v1/conversations"))
        #expect(paths.contains("/api/v1/tools"))
    }

    @Test("插件可取得自己的路由登记器")
    func exposesRegistrar() {
        let plugin = WebServerPlugin()
        let registrar = plugin.registrar(for: "com.test.plugin")

        registrar.contribute {
            WebRouteBuilder(prefix: "test")
                .get("/api/v1/test/ping") { _ in .text("pong") }
                .build()
        }

        #expect(registrar.registeredRoutes.count == 1)
    }
}
