import Testing
@testable import KernelCore

/// KernelCore 覆盖率补充：错误描述、插件 order 默认值与 `start(plugins:)` 启动顺序。
@Suite("KernelCore Coverage")
@MainActor
struct KernelCoreCoverageTests {

    // MARK: - Error descriptions

    @Test("KernelCoreError 的错误描述包含类型/标识信息")
    func errorDescriptions() {
        #expect(
            KernelCoreError.providerAlreadyRegistered(type: Int.self).errorDescription
                == "Provider 'Swift.Int' is already registered"
        )
        #expect(
            KernelCoreError.providerNotRegistered(type: String.self).errorDescription
                == "Provider 'Swift.String' is not registered"
        )
        #expect(
            KernelCoreError.pluginAlreadyRegistered(id: "p1").errorDescription
                == "Plugin 'p1' is already registered"
        )
        #expect(
            KernelCoreError.pluginNotFound(id: "p2").errorDescription
                == "Plugin 'p2' not found"
        )
    }

    // MARK: - SuperPlugin defaults

    @Test("order 默认值为 200，onBoot 默认不抛错")
    func pluginDefaults() throws {
        final class DefaultPlugin: SuperPlugin {
            let id = "default"
        }

        let plugin: any SuperPlugin = DefaultPlugin()
        #expect(plugin.order == 200)
        try plugin.onBoot(kernel: KernelCoreContainer())
    }

    // MARK: - start(plugins:)

    private final class OrderedPlugin: SuperPlugin {
        let id: String
        let order: Int
        static var bootOrder: [String] = []
        var onBootHandler: ((KernelCoreContainer) throws -> Void)?

        init(id: String, order: Int = 200, onBootHandler: ((KernelCoreContainer) throws -> Void)? = nil) {
            self.id = id
            self.order = order
            self.onBootHandler = onBootHandler
        }

        func onBoot(kernel: KernelCoreContainer) throws {
            Self.bootOrder.append(id)
            try onBootHandler?(kernel)
        }
    }

    @Test("start 按 order 升序执行 onBoot 并注册插件")
    func startBootsInOrder() throws {
        OrderedPlugin.bootOrder = []
        let core = KernelCoreContainer()

        try core.start(plugins: [
            OrderedPlugin(id: "late", order: 300),
            OrderedPlugin(id: "early", order: 100),
            OrderedPlugin(id: "default"),
        ])

        #expect(OrderedPlugin.bootOrder == ["early", "default", "late"])
        #expect(core.registeredPluginCount == 3)
        #expect(core.isPluginRegistered(id: "early"))
    }

    @Test("start 中 onBoot 抛错时向上传播")
    func startPropagatesOnBootError() throws {
        struct BootError: Error {}
        let core = KernelCoreContainer()

        #expect(throws: BootError.self) {
            try core.start(plugins: [
                OrderedPlugin(id: "ok", order: 100),
                OrderedPlugin(id: "bad", order: 200) { _ in throw BootError() },
            ])
        }
        // 抛错前已按 order 启动的插件仍保持注册
        #expect(core.isPluginRegistered(id: "ok"))
        #expect(core.isPluginRegistered(id: "bad"))
        #expect(!core.isPluginRegistered(id: "unbooted"))
    }

    @Test("start 重复 id 抛 pluginAlreadyRegistered")
    func startDuplicateThrows() {
        let core = KernelCoreContainer()

        #expect(throws: KernelCoreError.self) {
            try core.start(plugins: [
                OrderedPlugin(id: "dup", order: 100),
                OrderedPlugin(id: "dup", order: 200),
            ])
        }
        #expect(core.registeredPluginCount == 1)
    }
}
