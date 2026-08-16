import Testing
@testable import KernelCore

@Suite("KernelCore Async Lifecycle")
@MainActor
struct KernelCoreAsyncLifecycleTests {
    private final class EventLog {
        var values: [String] = []
    }

    private struct TestError: Error {}

    private final class AsyncPlugin: AsyncSuperPlugin {
        let id: String
        let order: Int
        let dependencies: [String]
        let events: EventLog
        var failReady = false

        init(
            id: String,
            order: Int = 200,
            dependencies: [String] = [],
            events: EventLog
        ) {
            self.id = id
            self.order = order
            self.dependencies = dependencies
            self.events = events
        }

        func onBootAsync(kernel: KernelCoreContainer) async throws {
            await Task.yield()
            events.values.append("boot:\(id)")
        }

        func onReadyAsync(kernel: KernelCoreContainer) async throws {
            await Task.yield()
            events.values.append("ready:\(id)")
            if failReady { throw TestError() }
        }

        func onShutdownAsync(kernel: KernelCoreContainer) async throws {
            await Task.yield()
            events.values.append("shutdown:\(id)")
        }
    }

    @Test("异步生命周期保持依赖顺序并可完整停止")
    func asyncStartAndStop() async throws {
        let log = EventLog()
        let base = AsyncPlugin(id: "base", order: 300, events: log)
        let feature = AsyncPlugin(id: "feature", order: 1, dependencies: ["base"], events: log)
        let kernel = KernelCoreContainer()

        try await kernel.startAsync(plugins: [feature, base])
        #expect(log.values == ["boot:base", "boot:feature", "ready:base", "ready:feature"])
        #expect(kernel.lifecycleState == .running)

        try await kernel.stopAsync()
        #expect(log.values.suffix(2) == ["shutdown:feature", "shutdown:base"])
        #expect(kernel.lifecycleState == .stopped)
    }

    @Test("同步入口拒绝异步插件，避免跳过异步实现")
    func syncStartRejectsAsyncPlugin() {
        let kernel = KernelCoreContainer()
        let plugin = AsyncPlugin(id: "async", events: EventLog())

        #expect(throws: KernelCoreError.self) {
            try kernel.start(plugins: [plugin])
        }
        #expect(kernel.lifecycleState == .stopped)
    }

    @Test("异步 Ready 失败会执行异步 Shutdown 并回滚")
    func asyncReadyFailureRollsBack() async {
        let log = EventLog()
        let plugin = AsyncPlugin(id: "async", events: log)
        plugin.failReady = true
        let kernel = KernelCoreContainer()

        await #expect(throws: TestError.self) {
            try await kernel.startAsync(plugins: [plugin])
        }
        #expect(log.values == ["boot:async", "ready:async", "shutdown:async"])
        #expect(!kernel.isPluginRegistered(id: "async"))
        #expect(kernel.lifecycleState == .failed)
    }
}
