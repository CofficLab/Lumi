import Testing
@testable import KernelCore

@Suite("KernelCore Lifecycle")
@MainActor
struct KernelCoreLifecycleTests {
    private protocol OwnedProviding: AnyObject {}
    private final class OwnedProvider: OwnedProviding {}

    private final class LifecyclePlugin: SuperPlugin {
        let id: String
        let order: Int
        let dependencies: [String]
        let metadata: PluginMetadata
        let events: EventLog
        var registerProvider = false
        var bootError: Error?
        var readyError: Error?
        var shutdownError: Error?

        init(
            id: String,
            order: Int = 200,
            dependencies: [String] = [],
            policy: PluginEnablePolicy = .enabledByDefault,
            events: EventLog
        ) {
            self.id = id
            self.order = order
            self.dependencies = dependencies
            self.metadata = PluginMetadata(id: id, policy: policy)
            self.events = events
        }

        func onBoot(kernel: KernelCoreContainer) throws {
            events.values.append("boot:\(id)")
            if registerProvider {
                try kernel.registerProvider(OwnedProviding.self, OwnedProvider())
            }
            if let bootError { throw bootError }
        }

        func onReady(kernel: KernelCoreContainer) throws {
            events.values.append("ready:\(id)")
            if let readyError { throw readyError }
        }

        func onShutdown(kernel: KernelCoreContainer) throws {
            events.values.append("shutdown:\(id)")
            if let shutdownError { throw shutdownError }
        }
    }

    private final class EventLog {
        var values: [String] = []
    }

    private struct TestError: Error {}

    @Test("依赖优先于 order，全部 Boot 后才进入 Ready")
    func dependenciesAndPhases() throws {
        let log = EventLog()
        let base = LifecyclePlugin(id: "base", order: 300, events: log)
        let feature = LifecyclePlugin(id: "feature", order: 1, dependencies: ["base"], events: log)
        let kernel = KernelCoreContainer()

        try kernel.start(plugins: [feature, base])

        #expect(log.values == ["boot:base", "boot:feature", "ready:base", "ready:feature"])
        #expect(kernel.lifecycleState == .running)
        #expect(kernel.allPlugins.map(\.id) == ["base", "feature"])
    }

    @Test("启动前拒绝缺失依赖且不改变内核")
    func missingDependency() {
        let log = EventLog()
        let plugin = LifecyclePlugin(id: "feature", dependencies: ["missing"], events: log)
        let kernel = KernelCoreContainer()

        #expect(throws: KernelCoreError.self) {
            try kernel.start(plugins: [plugin])
        }
        #expect(log.values.isEmpty)
        #expect(kernel.registeredPluginCount == 0)
        #expect(kernel.lifecycleState == .stopped)
    }

    @Test("启动前拒绝依赖环")
    func dependencyCycle() {
        let log = EventLog()
        let a = LifecyclePlugin(id: "a", dependencies: ["b"], events: log)
        let b = LifecyclePlugin(id: "b", dependencies: ["a"], events: log)
        let kernel = KernelCoreContainer()

        #expect(throws: KernelCoreError.self) {
            try kernel.start(plugins: [a, b])
        }
        #expect(kernel.registeredPluginCount == 0)
    }

    @Test("Ready 失败会逆序 Shutdown 并移除插件拥有的 Provider")
    func readyFailureRollsBack() {
        let log = EventLog()
        let base = LifecyclePlugin(id: "base", events: log)
        base.registerProvider = true
        let feature = LifecyclePlugin(id: "feature", order: 300, events: log)
        feature.readyError = TestError()
        let kernel = KernelCoreContainer()

        // 错误被包装为 pluginLifecycleFailed：原始 TestError 仍作为 underlying
        // 保留，同时补上此前完全缺失的归属信息（插件 id + 失败阶段）。
        // 只调用一次：失败后内核已进入 .failed，再次 start 抛的是生命周期状态错误。
        let thrown = Self.capturedError { try kernel.start(plugins: [base, feature]) }
        #expect(thrown is KernelCoreError)
        #expect(thrown?.lifecycleAttribution?.pluginID == "feature")
        #expect(thrown?.lifecycleAttribution?.phase == "ready")
        #expect(thrown?.lifecycleAttribution?.underlying is TestError)

        #expect(log.values.suffix(2) == ["shutdown:feature", "shutdown:base"])
        #expect(kernel.resolveProvider(OwnedProviding.self) == nil)
        #expect(kernel.registeredPluginCount == 0)
        #expect(kernel.lifecycleState == .failed)
    }

    /// 从一次预期失败的调用中取出错误。
    ///
    /// Swift Testing 的 `#expect(throws:)` 不支持尾随 `do` 块取回错误值，
    /// 因此统一用这个辅助函数捕获，保证断言的是内核真正抛出的那一个错误。
    private static func capturedError(_ operation: () throws -> Void) -> Error? {
        do {
            _ = try operation()
            Issue.record("expected the call to throw, but it returned")
            return nil
        } catch {
            return error
        }
    }

    @Test("Boot 失败会标出失败的插件与 boot 阶段")
    func bootFailureCarriesAttribution() {
        let log = EventLog()
        let plugin = LifecyclePlugin(id: "boom", events: log)
        plugin.bootError = TestError()
        let kernel = KernelCoreContainer()

        let thrown = Self.capturedError { try kernel.start(plugins: [plugin]) }
        #expect(thrown?.lifecycleAttribution?.pluginID == "boom")
        #expect(thrown?.lifecycleAttribution?.phase == "boot")
        #expect(thrown?.lifecycleAttribution?.underlying is TestError)

        // 归属信息必须排在最前面：宿主启动失败页会把 errorDescription 整段展示，
        // 用户复制去排查时要第一眼看到是哪个插件。
        let described = (thrown as? KernelCoreError)?.errorDescription ?? ""
        #expect(described.hasPrefix("Plugin 'boom' failed during boot"))
    }

    @Test("stop 逆序清理并可再次启动")
    func stopAndRestart() throws {
        let log = EventLog()
        let a = LifecyclePlugin(id: "a", events: log)
        let b = LifecyclePlugin(id: "b", dependencies: ["a"], events: log)
        let kernel = KernelCoreContainer()

        try kernel.start(plugins: [b, a])
        try kernel.stop()

        #expect(log.values.suffix(2) == ["shutdown:b", "shutdown:a"])
        #expect(kernel.lifecycleState == .stopped)
        #expect(kernel.registeredPluginCount == 0)

        try kernel.start(plugins: [a])
        #expect(kernel.lifecycleState == .running)
    }

    @Test("不能卸载仍被依赖的插件")
    func refusesUnloadWithDependents() throws {
        let log = EventLog()
        let a = LifecyclePlugin(id: "a", events: log)
        let b = LifecyclePlugin(id: "b", dependencies: ["a"], events: log)
        let kernel = KernelCoreContainer()
        try kernel.start(plugins: [a, b])

        #expect(throws: KernelCoreError.self) {
            try kernel.unloadPlugin(id: "a")
        }
        #expect(kernel.registeredPluginCount == 2)
    }
}
