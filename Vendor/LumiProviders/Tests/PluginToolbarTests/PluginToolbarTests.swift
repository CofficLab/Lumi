import Foundation
import KernelCore
import ProviderPluginManaging
import ProviderToolbar
import Testing
@testable import PluginToolbar

/// `PluginToolbarStateObserver` 的启用状态同步逻辑。
///
/// 该类型是纯状态搬运：把 `PluginManaging` 的插件集合与禁用集合推给
/// 各个 `ToolbarPluginStateProviding`。不涉及 SwiftUI 渲染，可完整覆盖。
@Suite("PluginToolbarStateObserver")
@MainActor
struct PluginToolbarStateObserverTests {

    /// 记录收到的插件状态，供断言。
    private final class RecordingStateProvider: ToolbarPluginStateProviding {
        private(set) var knownPluginIDs: Set<String> = []
        private(set) var disabledPluginIDs: Set<String> = []
        private(set) var callCount = 0

        func setPluginState(knownPluginIDs: Set<String>, disabledPluginIDs: Set<String>) {
            self.knownPluginIDs = knownPluginIDs
            self.disabledPluginIDs = disabledPluginIDs
            callCount += 1
        }
    }

    private final class TestPlugin: SuperPlugin {
        let id: String
        let order: Int
        let policy: PluginEnablePolicy

        init(id: String, order: Int = 200, policy: PluginEnablePolicy = .enabledByDefault) {
            self.id = id
            self.order = order
            self.policy = policy
        }

        var metadata: PluginMetadata { PluginMetadata(id: id, policy: policy) }

        func onBoot(kernel: KernelCoreContainer) throws {}
        func onShutdown(kernel: KernelCoreContainer) throws {}
    }

    @Test("初始化时立即同步一次当前插件状态")
    func syncsOnInit() throws {
        let kernel = KernelCoreContainer()
        let a = TestPlugin(id: "a")
        let b = TestPlugin(id: "b")
        try kernel.start(plugins: [a, b])
        let manager = DefaultPluginManaging(kernel: kernel)
        let provider = RecordingStateProvider()

        _ = PluginToolbarStateObserver(pluginManager: manager, providers: [provider])

        #expect(provider.knownPluginIDs == ["a", "b"])
        #expect(provider.disabledPluginIDs.isEmpty)
        #expect(provider.callCount == 1)
    }

    @Test("插件启用状态变化时重新同步禁用集合")
    func resyncsOnEnabledStateChanged() async throws {
        let kernel = KernelCoreContainer()
        let a = TestPlugin(id: "a")
        let b = TestPlugin(id: "b")
        try kernel.start(plugins: [a, b])
        let manager = DefaultPluginManaging(kernel: kernel)
        let provider = RecordingStateProvider()

        let observer = PluginToolbarStateObserver(pluginManager: manager, providers: [provider])
        #expect(provider.callCount == 1)

        _ = await manager.disablePlugin(id: "b")

        #expect(provider.knownPluginIDs == ["a", "b"])
        #expect(provider.disabledPluginIDs == ["b"])
        #expect(provider.callCount == 2)

        _ = await manager.enablePlugin(id: "b")

        #expect(provider.disabledPluginIDs.isEmpty)
        #expect(provider.callCount == 3)

        observer.cancel()
    }

    @Test("插件列表变化时重新同步已知集合")
    func resyncsOnListChanged() throws {
        let kernel = KernelCoreContainer()
        let a = TestPlugin(id: "a")
        try kernel.start(plugins: [a])
        let manager = DefaultPluginManaging(kernel: kernel)
        let provider = RecordingStateProvider()

        let observer = PluginToolbarStateObserver(pluginManager: manager, providers: [provider])
        #expect(provider.knownPluginIDs == ["a"])

        try manager.unloadPlugin(id: "a")

        #expect(provider.knownPluginIDs.isEmpty)
        #expect(provider.callCount == 2)

        observer.cancel()
    }

    @Test("同步结果广播到所有 provider")
    func broadcastsToEveryProvider() throws {
        let kernel = KernelCoreContainer()
        try kernel.start(plugins: [TestPlugin(id: "a")])
        let manager = DefaultPluginManaging(kernel: kernel)
        let first = RecordingStateProvider()
        let second = RecordingStateProvider()

        let observer = PluginToolbarStateObserver(pluginManager: manager, providers: [first, second])

        #expect(first.knownPluginIDs == ["a"])
        #expect(second.knownPluginIDs == ["a"])
        #expect(first.callCount == 1)
        #expect(second.callCount == 1)

        observer.cancel()
    }

    @Test("cancel 后不再接收插件事件")
    func stopsAfterCancel() async throws {
        let kernel = KernelCoreContainer()
        let plugin = TestPlugin(id: "a")
        try kernel.start(plugins: [plugin])
        let manager = DefaultPluginManaging(kernel: kernel)
        let provider = RecordingStateProvider()

        let observer = PluginToolbarStateObserver(pluginManager: manager, providers: [provider])
        #expect(provider.callCount == 1)

        observer.cancel()
        _ = await manager.disablePlugin(id: "a")

        #expect(provider.callCount == 1)
    }

    @Test("cancel 可重复调用且保持幂等")
    func cancelIsIdempotent() throws {
        let kernel = KernelCoreContainer()
        try kernel.start(plugins: [])
        let manager = DefaultPluginManaging(kernel: kernel)
        let observer = PluginToolbarStateObserver(
            pluginManager: manager,
            providers: [RecordingStateProvider()]
        )

        observer.cancel()
        observer.cancel()
    }
}

/// `PluginToolbar` 插件入口的装配分支。
@Suite("PluginToolbar lifecycle")
@MainActor
struct PluginToolbarLifecycleTests {

    private final class TestPlugin: SuperPlugin {
        let id: String
        let order = 200
        let policy: PluginEnablePolicy = .enabledByDefault

        init(id: String) {
            self.id = id
        }

        var metadata: PluginMetadata { PluginMetadata(id: id, policy: policy) }
        func onBoot(kernel: KernelCoreContainer) throws {}
        func onShutdown(kernel: KernelCoreContainer) throws {}
    }

    /// `DefaultToolbarProviding` 只实现 macOS 侧契约，iOS 导航栏用最小 stub。
    private final class StubNavigationBarProvider: IOSNavigationBarProviding {
        var navigationBarItems: [IOSNavigationBarItem] = []
        private(set) var knownPluginIDs: Set<String> = []
        private(set) var disabledPluginIDs: Set<String> = []
        private(set) var callCount = 0

        func registerNavigationBarItems(_ items: [IOSNavigationBarItem]) {
            navigationBarItems = items
        }

        func setPluginState(knownPluginIDs: Set<String>, disabledPluginIDs: Set<String>) {
            self.knownPluginIDs = knownPluginIDs
            self.disabledPluginIDs = disabledPluginIDs
            callCount += 1
        }
    }

    @Test("宿主可注入自定义插件 id")
    func customPluginIDIsApplied() {
        let plugin = PluginToolbar(id: "com.example.custom.plugin.toolbar")

        #expect(plugin.id == "com.example.custom.plugin.toolbar")
        #expect(plugin.metadata.id == plugin.id)
        #expect(plugin.order == 0)
        #expect(PluginToolbar.defaultPluginID == "com.coffic.shared.plugin.toolbar")
    }

    @Test("注册 macOS 工具栏 provider 后开始跟踪启用状态")
    func attachesToolbarStateObserver() throws {
        let kernel = KernelCoreContainer()
        try kernel.start(plugins: [TestPlugin(id: "a")])
        try kernel.registerProvider(
            (any PluginManaging).self,
            DefaultPluginManaging(kernel: kernel)
        )
        try kernel.registerProvider(
            (any ToolbarProviding).self,
            DefaultToolbarProviding()
        )

        let plugin = PluginToolbar()
        try plugin.onBoot(kernel: kernel)
        try plugin.onReady(kernel: kernel)
        try plugin.onShutdown(kernel: kernel)
    }

    @Test("只注册 iOS 导航栏 provider 也可正常装配")
    func attachesWithOnlyNavigationBarProvider() throws {
        let kernel = KernelCoreContainer()
        try kernel.start(plugins: [TestPlugin(id: "a")])
        try kernel.registerProvider(
            (any PluginManaging).self,
            DefaultPluginManaging(kernel: kernel)
        )
        try kernel.registerProvider(
            (any IOSNavigationBarProviding).self,
            StubNavigationBarProvider()
        )

        let plugin = PluginToolbar()
        try plugin.onReady(kernel: kernel)
        try plugin.onShutdown(kernel: kernel)
    }

    @Test("缺少 PluginManaging 时跳过跟踪且不崩溃")
    func skipsWhenPluginManagingMissing() throws {
        let kernel = KernelCoreContainer()
        try kernel.start(plugins: [])
        try kernel.registerProvider((any ToolbarProviding).self, DefaultToolbarProviding())

        let plugin = PluginToolbar()
        try plugin.onReady(kernel: kernel)
        try plugin.onShutdown(kernel: kernel)
    }

    @Test("没有任何 toolbar provider 时跳过跟踪且不崩溃")
    func skipsWhenNoToolbarProvider() throws {
        let kernel = KernelCoreContainer()
        try kernel.start(plugins: [])
        try kernel.registerProvider(
            (any PluginManaging).self,
            DefaultPluginManaging(kernel: kernel)
        )

        let plugin = PluginToolbar()
        try plugin.onReady(kernel: kernel)
        try plugin.onShutdown(kernel: kernel)
    }

    @Test("未装配时调用 shutdown 也不崩溃")
    func shutdownWithoutReadyIsSafe() throws {
        let kernel = KernelCoreContainer()
        try kernel.start(plugins: [])

        let plugin = PluginToolbar()
        try plugin.onShutdown(kernel: kernel)
    }
}
