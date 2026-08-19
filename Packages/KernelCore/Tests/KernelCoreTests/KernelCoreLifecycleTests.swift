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

        #expect(throws: TestError.self) {
            try kernel.start(plugins: [base, feature])
        }

        #expect(log.values.suffix(2) == ["shutdown:feature", "shutdown:base"])
        #expect(kernel.resolveProvider(OwnedProviding.self) == nil)
        #expect(kernel.registeredPluginCount == 0)
        #expect(kernel.lifecycleState == .failed)
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
