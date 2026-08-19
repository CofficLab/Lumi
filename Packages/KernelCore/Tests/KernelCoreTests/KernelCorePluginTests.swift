import Testing
@testable import KernelCore

/// KernelCore 插件注入机制的测试：插件的注册/解析/注销语义。
///
/// 模块对应：`Sources/KernelCore/KernelCore+Plugin.swift`。
/// 插件按 `id` 注入（与 Provider 按类型注入互补）。
@Suite("KernelCore Plugin Registry")
@MainActor
struct KernelCorePluginTests {

    private final class MockPlugin: SuperPlugin {
        let id: String
        let metadata: PluginMetadata
        init(id: String) {
            self.id = id
            self.metadata = PluginMetadata(id: id)
        }
    }

    @Test("注入后可通过 id 解析")
    func registerAndResolve() throws {
        let core = KernelCoreContainer()
        let plugin = MockPlugin(id: "test.plugin")

        try core.registerPlugin(plugin)

        let resolved = core.resolvePlugin(id: "test.plugin")
        #expect(resolved != nil)
        #expect(resolved as? MockPlugin === plugin)
        #expect(core.isPluginRegistered(id: "test.plugin"))
        #expect(core.registeredPluginCount == 1)
        #expect(core.allPlugins.count == 1)
    }

    @Test("重复注入同 id 抛错")
    func duplicateRegistrationThrows() throws {
        let core = KernelCoreContainer()
        try core.registerPlugin(MockPlugin(id: "a"))

        #expect(throws: KernelCoreError.self) {
            try core.registerPlugin(MockPlugin(id: "a"))
        }
        #expect(core.registeredPluginCount == 1)
    }

    @Test("未注入的 id 解析为 nil")
    func resolveMissingReturnsNil() {
        let core = KernelCoreContainer()
        #expect(core.resolvePlugin(id: "missing") == nil)
        #expect(!core.isPluginRegistered(id: "missing"))
        #expect(core.registeredPluginCount == 0)
    }

    @Test("注销后不可再解析")
    func unregisterRemovesPlugin() throws {
        let core = KernelCoreContainer()
        try core.registerPlugin(MockPlugin(id: "a"))

        core.unregisterPlugin(id: "a")

        #expect(core.resolvePlugin(id: "a") == nil)
        #expect(!core.isPluginRegistered(id: "a"))
    }

    @Test("注销未注入 id 为幂等 no-op")
    func unregisterMissingIsNoOp() {
        let core = KernelCoreContainer()
        core.unregisterPlugin(id: "missing")
        #expect(core.registeredPluginCount == 0)
    }

    @Test("多个插件按 id 互不干扰")
    func distinctPluginIDsAreIndependent() throws {
        let core = KernelCoreContainer()
        let a = MockPlugin(id: "a")
        let b = MockPlugin(id: "b")

        try core.registerPlugin(a)
        try core.registerPlugin(b)

        #expect(core.resolvePlugin(id: "a") as? MockPlugin === a)
        #expect(core.resolvePlugin(id: "b") as? MockPlugin === b)
        #expect(core.registeredPluginCount == 2)
    }

    @Test("插件与 Provider 可共存")
    func pluginsAndProvidersCoexist() throws {
        let core = KernelCoreContainer()
        let plugin = MockPlugin(id: "p")
        try core.registerPlugin(plugin)

        let provider = CountingProvider()
        try core.registerProvider(CountingProviding.self, provider)

        #expect(core.resolvePlugin(id: "p") as? MockPlugin === plugin)
        #expect(core.resolveProvider(CountingProviding.self) as? CountingProvider === provider)
        #expect(core.registeredPluginCount == 1)
        #expect(core.registeredProviderCount == 1)
    }

    // MARK: - 测试用 Provider 协议

    private protocol CountingProviding: AnyObject {}

    private final class CountingProvider: CountingProviding {}
}
