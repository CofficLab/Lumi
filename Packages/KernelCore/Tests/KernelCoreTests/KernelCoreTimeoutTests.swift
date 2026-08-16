import Testing
@testable import KernelCore

@Suite("KernelCore Lifecycle Timeout & Cancellation")
@MainActor
struct KernelCoreTimeoutTests {
    private final class EventLog {
        var values: [String] = []
    }

    /// 模拟响应取消的慢插件：各阶段 delay 独立可配，Task.sleep 在取消时立即抛出。
    private final class SlowPlugin: AsyncSuperPlugin {
        let id: String
        let order: Int
        let bootDelay: Duration
        let readyDelay: Duration
        let shutdownDelay: Duration
        let events: EventLog

        init(
            id: String,
            order: Int = 200,
            bootDelay: Duration = .milliseconds(10),
            readyDelay: Duration = .milliseconds(10),
            shutdownDelay: Duration = .milliseconds(10),
            events: EventLog
        ) {
            self.id = id
            self.order = order
            self.bootDelay = bootDelay
            self.readyDelay = readyDelay
            self.shutdownDelay = shutdownDelay
            self.events = events
        }

        func onBootAsync(kernel: KernelCoreContainer) async throws {
            events.values.append("boot:start:\(id)")
            try await Task.sleep(for: bootDelay)
            events.values.append("boot:end:\(id)")
        }

        func onReadyAsync(kernel: KernelCoreContainer) async throws {
            events.values.append("ready:start:\(id)")
            try await Task.sleep(for: readyDelay)
            events.values.append("ready:end:\(id)")
        }

        func onShutdownAsync(kernel: KernelCoreContainer) async throws {
            events.values.append("shutdown:start:\(id)")
            try await Task.sleep(for: shutdownDelay)
            events.values.append("shutdown:end:\(id)")
        }
    }

    private func shortTimeout() -> KernelLifecycleTimeout {
        KernelLifecycleTimeout(
            boot: .milliseconds(100),
            ready: .milliseconds(100),
            shutdown: .milliseconds(100)
        )
    }

    @Test("boot 超时抛 lifecycleTimeout 并完整回滚")
    func bootTimeoutRollsBack() async {
        let log = EventLog()
        let plugin = SlowPlugin(id: "slow", bootDelay: .seconds(5), events: log)
        let kernel = KernelCoreContainer()

        await #expect(throws: KernelCoreError.self) {
            try await kernel.startAsync(plugins: [plugin], timeout: shortTimeout())
        }
        // 超时后插件不得残留：已注册状态与贡献全部清理
        #expect(!kernel.isPluginRegistered(id: "slow"))
        #expect(kernel.lifecycleState == .failed)
        // 插件确实开始执行过（进入过 boot）
        #expect(log.values.contains("boot:start:slow"))
    }

    @Test("ready 超时同样触发回滚且不残留")
    func readyTimeoutRollsBack() async {
        let log = EventLog()
        let plugin = SlowPlugin(id: "slow-ready", readyDelay: .seconds(5), events: log)
        let kernel = KernelCoreContainer()

        await #expect(throws: KernelCoreError.self) {
            try await kernel.startAsync(plugins: [plugin], timeout: shortTimeout())
        }
        #expect(!kernel.isPluginRegistered(id: "slow-ready"))
        #expect(kernel.lifecycleState == .failed)
        // boot 快速通过、ready 进入后超时
        #expect(log.values.contains("boot:end:slow-ready"))
        #expect(log.values.contains("ready:start:slow-ready"))
    }

    @Test("shutdown 超时抛出首个错误但插件仍被清理")
    func shutdownTimeoutStillCleansUp() async throws {
        let log = EventLog()
        let slow = SlowPlugin(id: "slow-shutdown", shutdownDelay: .seconds(2), events: log)
        let fast = SlowPlugin(id: "fast-shutdown", events: log)
        let kernel = KernelCoreContainer()

        try await kernel.startAsync(
            plugins: [slow, fast],
            timeout: KernelLifecycleTimeout(boot: .seconds(30), ready: .seconds(30))
        )
        #expect(kernel.lifecycleState == .running)

        await #expect(throws: KernelCoreError.self) {
            try await kernel.stopAsync(timeout: shortTimeout())
        }
        // 无论是否超时，插件注册表都必须清空，内核回到 stopped
        #expect(!kernel.isPluginRegistered(id: "slow-shutdown"))
        #expect(!kernel.isPluginRegistered(id: "fast-shutdown"))
        #expect(kernel.lifecycleState == .stopped)
    }

    @Test("回滚阶段的 shutdown 清理同样受超时保护")
    func rollbackShutdownHasTimeout() async {
        let log = EventLog()
        let plugin = SlowPlugin(
            id: "rollback-slow",
            bootDelay: .seconds(5),      // boot 超时触发回滚
            shutdownDelay: .seconds(5),  // 回滚清理也慢，不得无限等待
            events: log
        )
        // 用事件日志验证回滚确实开始
        let kernel = KernelCoreContainer()
        let start = ContinuousClock.now

        await #expect(throws: KernelCoreError.self) {
            try await kernel.startAsync(plugins: [plugin], timeout: shortTimeout())
        }
        let elapsed = start.duration(to: .now)
        // 回滚 shutdown 被超时打断：总耗时应远小于 boot(5s)+shutdown(5s)
        #expect(elapsed < .seconds(8))
        #expect(!kernel.isPluginRegistered(id: "rollback-slow"))
    }

    @Test("默认超时配置不干扰正常快速启动")
    func defaultTimeoutAllowsFastBoot() async throws {
        let log = EventLog()
        let plugin = SlowPlugin(id: "fast", events: log)
        let kernel = KernelCoreContainer()

        try await kernel.startAsync(plugins: [plugin])
        #expect(kernel.lifecycleState == .running)
        #expect(kernel.isPluginRegistered(id: "fast"))
        try await kernel.stopAsync()
        #expect(kernel.lifecycleState == .stopped)
    }

    @Test("外部取消传播到生命周期并回滚")
    func externalCancellationRollsBack() async {
        let log = EventLog()
        let plugin = SlowPlugin(id: "cancelled", bootDelay: .seconds(5), events: log)
        let kernel = KernelCoreContainer()

        let task = Task { @MainActor in
            try await kernel.startAsync(plugins: [plugin], timeout: nil)
        }
        // 给启动一点时间进入 boot，然后取消
        try? await Task.sleep(for: .milliseconds(50))
        task.cancel()

        do {
            _ = try await task.value
            Issue.record("外部取消后 startAsync 应当抛出错误")
        } catch is CancellationError {
            // 期望路径：任务取消传播
        } catch {
            Issue.record("期望 CancellationError，得到 \(error)")
        }
        #expect(!kernel.isPluginRegistered(id: "cancelled"))
        #expect(kernel.lifecycleState == .failed)
    }
}
