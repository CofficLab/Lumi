import Foundation
import KernelCore
import ProviderDeveloperMode
import ProviderToolbar
import Testing
@testable import PluginDeveloperMode

// MARK: - 测试替身

/// 可记录调用的开发者模式能力替身。
@MainActor
private final class StubDeveloperModeCapability: DeveloperModeCapability {
    var isEnabled: Bool

    private(set) var toggleCount = 0
    private var observer: ((DeveloperModeProvidingEvent) -> Void)?
    private var handle = StubDeveloperModeHandle()

    init(isEnabled: Bool = false) {
        self.isEnabled = isEnabled
    }

    func toggle() {
        toggleCount += 1
    }

    func addObserver(
        _ callback: @escaping (DeveloperModeProvidingEvent) -> Void
    ) -> any DeveloperModeProvidingObserverHandle {
        observer = callback
        handle.onCancel = { [weak self] in self?.observer = nil }
        return handle
    }

    /// 模拟 Provider 广播状态变化。
    func emit(_ event: DeveloperModeProvidingEvent) {
        observer?(event)
    }

    var isObserving: Bool { observer != nil }
}

/// 可计数的观察者注销令牌。
@MainActor
private final class StubDeveloperModeHandle: DeveloperModeProvidingObserverHandle {
    private(set) var cancelCount = 0
    var onCancel: (() -> Void)?

    func cancel() {
        cancelCount += 1
        onCancel?()
    }
}

// MARK: - ViewModel

@Suite("开发者模式 ViewModel")
@MainActor
struct DeveloperModeViewModelTests {

    @Test("初始状态为关闭")
    func startsDisabled() {
        let capability = StubDeveloperModeCapability()
        let viewModel = DeveloperModeViewModel(capability: capability)

        #expect(viewModel.isEnabled == false)
    }

    @Test("update 写入外部状态")
    func updateAppliesExternalState() {
        let capability = StubDeveloperModeCapability()
        let viewModel = DeveloperModeViewModel(capability: capability)

        viewModel.update(isEnabled: true)
        #expect(viewModel.isEnabled)

        viewModel.update(isEnabled: false)
        #expect(viewModel.isEnabled == false)
    }

    @Test("toggle 转发给能力层")
    func toggleForwardsToCapability() {
        let capability = StubDeveloperModeCapability()
        let viewModel = DeveloperModeViewModel(capability: capability)

        viewModel.toggle()

        #expect(capability.toggleCount == 1)
    }
}

// MARK: - Observer

@Suite("开发者模式 Observer")
@MainActor
struct DeveloperModeObserverTests {

    @Test("初始化时同步能力层当前状态")
    func syncsInitialState() {
        let capability = StubDeveloperModeCapability(isEnabled: true)
        let viewModel = DeveloperModeViewModel(capability: capability)

        let observer = DeveloperModeObserver(capability: capability, viewModel: viewModel)
        defer { observer.cancel() }

        #expect(viewModel.isEnabled)
    }

    @Test("收到 enabledChanged 事件后更新 ViewModel")
    func appliesEnabledChangedEvent() {
        let capability = StubDeveloperModeCapability()
        let viewModel = DeveloperModeViewModel(capability: capability)
        let observer = DeveloperModeObserver(capability: capability, viewModel: viewModel)
        defer { observer.cancel() }

        capability.emit(.enabledChanged(true))

        #expect(viewModel.isEnabled)
    }

    @Test("取消后释放订阅并停止更新")
    func cancelStopsUpdates() {
        let capability = StubDeveloperModeCapability()
        let viewModel = DeveloperModeViewModel(capability: capability)
        let observer = DeveloperModeObserver(capability: capability, viewModel: viewModel)

        observer.cancel()

        #expect(capability.isObserving == false)

        capability.emit(.enabledChanged(true))
        #expect(viewModel.isEnabled == false)
    }
}

// MARK: - 能力适配器

@Suite("开发者模式能力适配器")
@MainActor
struct DeveloperModeCapabilityAdapterTests {

    @Test("转发启用状态与切换动作")
    func forwardsToProvider() {
        let provider = DefaultDeveloperModeProviding()
        let adapter = DeveloperModeCapabilityAdapter(provider: provider)

        #expect(adapter.isEnabled == false)

        adapter.toggle()
        #expect(adapter.isEnabled)
        #expect(provider.isEnabled)
    }

    @Test("Provider 释放后按关闭处理")
    func treatsReleasedProviderAsDisabled() {
        var provider: DefaultDeveloperModeProviding? = DefaultDeveloperModeProviding()
        let adapter = DeveloperModeCapabilityAdapter(provider: provider!)
        provider = nil

        #expect(adapter.isEnabled == false)
        adapter.toggle()
    }

    @Test("观察者订阅透传到 Provider")
    func forwardsObserverSubscription() {
        let provider = DefaultDeveloperModeProviding()
        let adapter = DeveloperModeCapabilityAdapter(provider: provider)
        var received: [Bool] = []

        let handle = adapter.addObserver { event in
            if case let .enabledChanged(value) = event {
                received.append(value)
            }
        }
        provider.setEnabled(true)
        handle.cancel()

        #expect(received == [true])
    }
}

// MARK: - 插件生命周期

@Suite("开发者模式插件生命周期")
@MainActor
struct DeveloperModePluginLifecycleTests {

    @Test("缺少开发者模式 Provider 时不注册工具栏项也不抛错")
    func bootWithoutProviderIsNoop() throws {
        let kernel = KernelCoreContainer()
        let toolbar = DefaultToolbarProviding()
        try kernel.registerProvider((any ToolbarProviding).self, toolbar)

        let plugin = DeveloperModePlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(toolbar.toolbarItems.isEmpty)
    }

    @Test("缺少工具栏 Provider 时启动不抛错")
    func bootWithoutToolbarIsNoop() throws {
        let kernel = KernelCoreContainer()
        try kernel.registerProvider((any DeveloperModeProviding).self, DefaultDeveloperModeProviding())

        let plugin = DeveloperModePlugin()
        try plugin.onBoot(kernel: kernel)
        defer { try? plugin.onShutdown(kernel: kernel) }

        #expect(kernel.resolveProvider((any DeveloperModeProviding).self) != nil)
    }

    @Test("关闭时移除工具栏项")
    func shutdownRemovesToolbarItems() throws {
        let kernel = KernelCoreContainer()
        let toolbar = DefaultToolbarProviding()
        try kernel.registerProvider((any ToolbarProviding).self, toolbar)
        try kernel.registerProvider((any DeveloperModeProviding).self, DefaultDeveloperModeProviding())

        let plugin = DeveloperModePlugin()
        try plugin.onBoot(kernel: kernel)
        #expect(toolbar.toolbarItems.isEmpty == false)

        try plugin.onShutdown(kernel: kernel)

        #expect(toolbar.toolbarItems.isEmpty)
    }
}
