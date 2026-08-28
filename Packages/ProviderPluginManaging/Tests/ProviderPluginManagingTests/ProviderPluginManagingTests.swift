import KernelCore
import ProviderPluginControl
import ProviderPluginManaging
import Testing

@Suite("ProviderPluginManaging")
@MainActor
struct ProviderPluginManagingTests {
    private final class TestPlugin: SuperPlugin {
        let id: String
        let order: Int
        let policy: PluginEnablePolicy
        var bootCount = 0
        var shutdownCount = 0

        init(id: String, order: Int = 200, policy: PluginEnablePolicy = .enabledByDefault) {
            self.id = id
            self.order = order
            self.policy = policy
        }

        var metadata: PluginMetadata { PluginMetadata(id: id, policy: policy) }

        func onBoot(kernel: KernelCoreContainer) throws { bootCount += 1 }
        func onShutdown(kernel: KernelCoreContainer) throws { shutdownCount += 1 }
    }

    @Test("枚举与查询内核中的 SuperPlugin")
    func enumeratesAndQueriesPlugins() throws {
        let kernel = KernelCoreContainer()
        let a = TestPlugin(id: "a", order: 10)
        let b = TestPlugin(id: "b", order: 20, policy: .required)
        try kernel.start(plugins: [a, b])
        let manager = DefaultPluginManaging(kernel: kernel)

        #expect(manager.pluginCount == 2)
        #expect(manager.allPlugins.map(\.id) == ["a", "b"])
        #expect(manager.configurablePlugins.map(\.id) == ["a"])
        #expect(manager.plugin(id: "a")?.id == "a")
        #expect(manager.plugin(id: "missing") == nil)
        #expect(manager.isRegistered(id: "a"))
        #expect(!manager.isRegistered(id: "missing"))
        #expect(manager.enabledCount == 2)
    }

    @Test("启停控制委托给 PluginControlling")
    func delegatesEnableDisable() async throws {
        let kernel = KernelCoreContainer()
        let plugin = TestPlugin(id: "runtime", policy: .enabledByDefault)
        try kernel.start(plugins: [plugin])
        let manager = DefaultPluginManaging(kernel: kernel)

        #expect(manager.isEnabled(id: plugin.id))
        #expect(await manager.disablePlugin(id: plugin.id))
        #expect(!manager.isEnabled(id: plugin.id))

        #expect(await manager.enablePlugin(id: plugin.id))
        #expect(manager.isEnabled(id: plugin.id))
        #expect(manager.lastErrorDescription == nil)
    }

    @Test("重载与卸载插件")
    func reloadAndUnload() throws {
        let kernel = KernelCoreContainer()
        let plugin = TestPlugin(id: "reloadable")
        try kernel.start(plugins: [plugin])
        let manager = DefaultPluginManaging(kernel: kernel)

        // 重载：卸载（onShutdown）后按依赖图重新启动（onBoot 再次执行）。
        try manager.reloadPlugin(id: plugin.id)
        #expect(manager.isRegistered(id: plugin.id))
        #expect(plugin.bootCount == 2)
        #expect(plugin.shutdownCount == 1)

        // 卸载：插件不再注册。
        try manager.unloadPlugin(id: plugin.id)
        #expect(!manager.isRegistered(id: plugin.id))
        #expect(plugin.shutdownCount == 2)
    }

    @Test("未知插件与未附加内核时报错")
    func reportsErrors() {
        let kernel = KernelCoreContainer()
        try? kernel.start(plugins: [])
        let manager = DefaultPluginManaging(kernel: kernel)

        #expect(throws: PluginManagingError.pluginNotFound(id: "missing")) {
            try manager.reloadPlugin(id: "missing")
        }

        let detached = DefaultPluginManaging()
        #expect(throws: PluginManagingError.kernelNotAttached) {
            try detached.unloadPlugin(id: "a")
        }
    }

    // MARK: - Observer Tests

    @Test("观察者在卸载插件时收到 listChanged 事件")
    func observerReceivesListChangedOnUnload() throws {
        let kernel = KernelCoreContainer()
        let plugin = TestPlugin(id: "obs-test")
        try kernel.start(plugins: [plugin])
        let manager = DefaultPluginManager(kernel: kernel)

        var receivedEvents: [PluginManagingEvent] = []
        let handle = manager.addPluginObserver { event in
            receivedEvents.append(event)
        }

        try manager.unloadPlugin(id: plugin.id)

        #expect(receivedEvents.count == 1)
        if case .listChanged = receivedEvents.first {} else {
            Issue.record("Expected listChanged event")
        }

        handle.cancel()
    }

    @Test("观察者在重载插件时收到 listChanged 事件")
    func observerReceivesListChangedOnReload() throws {
        let kernel = KernelCoreContainer()
        let plugin = TestPlugin(id: "obs-reload")
        try kernel.start(plugins: [plugin])
        let manager = DefaultPluginManager(kernel: kernel)

        var receivedEvents: [PluginManagingEvent] = []
        let handle = manager.addPluginObserver { event in
            receivedEvents.append(event)
        }

        try manager.reloadPlugin(id: plugin.id)

        #expect(receivedEvents.count == 1)
        if case .listChanged = receivedEvents.first {} else {
            Issue.record("Expected listChanged event")
        }

        handle.cancel()
    }

    @Test("观察者在启用/禁用插件时收到 enabledStateChanged 事件")
    func observerReceivesEnabledStateChanged() async throws {
        let kernel = KernelCoreContainer()
        let plugin = TestPlugin(id: "obs-toggle", policy: .enabledByDefault)
        try kernel.start(plugins: [plugin])
        let manager = DefaultPluginManager(kernel: kernel)

        var receivedEvents: [PluginManagingEvent] = []
        let handle = manager.addPluginObserver { event in
            receivedEvents.append(event)
        }

        _ = await manager.disablePlugin(id: plugin.id)
        _ = await manager.enablePlugin(id: plugin.id)

        #expect(receivedEvents.count == 2)

        if case let .enabledStateChanged(pluginID, enabled) = receivedEvents[0] {
            #expect(pluginID == "obs-toggle")
            #expect(enabled == false)
        } else {
            Issue.record("Expected enabledStateChanged(false) event")
        }

        if case let .enabledStateChanged(pluginID, enabled) = receivedEvents[1] {
            #expect(pluginID == "obs-toggle")
            #expect(enabled == true)
        } else {
            Issue.record("Expected enabledStateChanged(true) event")
        }

        handle.cancel()
    }

    @Test("观察者取消后不再收到事件")
    func observerStopsAfterCancel() async throws {
        let kernel = KernelCoreContainer()
        let plugin = TestPlugin(id: "obs-cancel", policy: .enabledByDefault)
        try kernel.start(plugins: [plugin])
        let manager = DefaultPluginManager(kernel: kernel)

        var receiveCount = 0
        let handle = manager.addPluginObserver { _ in
            receiveCount += 1
        }

        _ = await manager.disablePlugin(id: plugin.id)
        #expect(receiveCount == 1)

        handle.cancel()

        _ = await manager.enablePlugin(id: plugin.id)
        #expect(receiveCount == 1) // 应该不再增加
    }

    @Test("令牌释放后自动停止接收事件")
    func observerStopsAfterDealloc() async throws {
        let kernel = KernelCoreContainer()
        let plugin = TestPlugin(id: "obs-dealloc", policy: .enabledByDefault)
        try kernel.start(plugins: [plugin])
        let manager = DefaultPluginManager(kernel: kernel)

        var receiveCount = 0
        do {
            let _ = manager.addPluginObserver { _ in
                receiveCount += 1
            }
            // handle 在 do 作用域结束后被释放
        }

        _ = await manager.disablePlugin(id: plugin.id)
        // 令牌已释放，不应再收到事件
        #expect(receiveCount == 0)
    }

    @Test("多个观察者同时收到事件")
    func multipleObserversReceiveEvents() async throws {
        let kernel = KernelCoreContainer()
        let plugin = TestPlugin(id: "obs-multi", policy: .enabledByDefault)
        try kernel.start(plugins: [plugin])
        let manager = DefaultPluginManager(kernel: kernel)

        var countA = 0
        var countB = 0
        let handleA = manager.addPluginObserver { _ in countA += 1 }
        let handleB = manager.addPluginObserver { _ in countB += 1 }

        _ = await manager.disablePlugin(id: plugin.id)

        #expect(countA == 1)
        #expect(countB == 1)

        handleA.cancel()

        _ = await manager.enablePlugin(id: plugin.id)

        #expect(countA == 1) // A 已取消
        #expect(countB == 2) // B 仍接收

        handleB.cancel()
    }
}
