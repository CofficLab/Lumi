import Foundation
import KernelCore
import ProviderActivityBar
import ProviderChatSection
import ProviderContentView
import ProviderStorage
import Testing
@testable import DisplayControlPlugin

/// 运行时禁用生命周期回归（#460）。
///
/// Kernel 的 `disablePlugin` 只调用 `onDisable` 并撤回经 `trackContribution`
/// 注册的贡献，不会调用 `onShutdown`，也不会过滤插件直接写入 ActivityBar 的
/// 入口、观察器的 5 秒刷新定时器/订阅，或 `DisplayService` 150ms 防抖窗口内
/// 尚未执行的硬件写入。这些都必须由插件在 `onDisable` 自行清理。
///
/// 涉及进程级单例 `DisplayService.shared` 与运行时目录注入，套件串行执行，
/// 并在 defer 中复位，避免污染其他用例。
@Suite("DisplayControl 禁用生命周期", .serialized)
@MainActor
struct DisplayControlDisableLifecycleTests {

    @Test("运行时禁用停止周期刷新、取消未执行的硬件写入并撤回入口，重新启用恢复（**回归 #460**）")
    func disableStopsRefreshAndCancelsPendingWrites() async throws {
        let root = DisplayControlTestDoubles.makeTemporaryDirectory("disable-lifecycle")
        defer {
            DisplayService.shared.cancelPendingWrites()
            DisplayService.shared.setDisplaysForTesting([])
            DisplayControlRuntime.reset()
            try? FileManager.default.removeItem(at: root)
        }

        let kernel = KernelCoreContainer()
        let activity = DefaultActivityBarProviding()
        try kernel.registerProvider((any ActivityBarProviding).self, activity)
        try kernel.registerProvider((any ChatSectionProviding).self, DefaultChatSectionProviding())
        try kernel.registerProvider((any ContentViewProviding).self, DefaultContentViewProviding())
        try kernel.registerProvider(
            (any StorageProviding).self,
            DisplayControlTestDoubles.StubStorageProvider(root: root)
        )

        let plugin = DisplayControlPlugin()
        let entryID = "\(plugin.id).entry"
        try kernel.start(plugins: [plugin])
        // 插件 disabledByDefault：start 只注册不 Boot，需显式启用完成初始化。
        try await kernel.enablePlugin(id: plugin.id)
        #expect(activity.items.contains { $0.id == entryID })
        #expect(plugin.isObserverRunningForTesting)

        // 在 150ms 防抖窗口内构造一个尚未执行的硬件写入。
        let display = ControlledDisplay(
            id: 1,
            storageID: "test-display",
            name: "Test Display",
            isBuiltIn: false,
            supportsBrightness: true,
            supportsVolume: false,
            supportsContrast: false,
            brightness: 50,
            volume: 40,
            contrast: 75
        )
        DisplayService.shared.setDisplaysForTesting([display])
        DisplayService.shared.setValue(80, for: .brightness, displayID: 1)
        #expect(DisplayService.shared.hasPendingWritesForTesting)

        try await kernel.disablePlugin(id: plugin.id)
        #expect(!activity.items.contains { $0.id == entryID })
        #expect(!plugin.isObserverRunningForTesting)
        #expect(!DisplayService.shared.hasPendingWritesForTesting)

        try await kernel.enablePlugin(id: plugin.id)
        #expect(activity.items.contains { $0.id == entryID })
        #expect(plugin.isObserverRunningForTesting)

        try kernel.stop()
        #expect(!activity.items.contains { $0.id == entryID })
        #expect(!plugin.isObserverRunningForTesting)
        #expect(!DisplayService.shared.hasPendingWritesForTesting)
    }
}