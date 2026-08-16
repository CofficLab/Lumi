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
}
