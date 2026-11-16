import Foundation
import KernelCore
import Testing
@testable import TextActionsPlugin

/// 回归 #303：设置开关与插件生命周期必须统一持有并清理同一个选区监听。
///
/// 历史实现有两个独立监听（`TextSelectionObserver` 与 `TextSelectionManager`），
/// 开关只控其一、插件停用只清其一，导致关闭功能或停用插件后仍读取其它应用
/// 的选区并弹浮层。重构后只剩一个监听，本组用例锁定「开关关闭」与「插件停用」
/// 两条路径都必须停止它。
@Suite("划词监听清理", .serialized)
@MainActor
struct TextActionsListenerCleanupTests {

    @Test("关闭设置开关会停止选区监听")
    func toggleOffStopsSelectionMonitoring() {
        let (monitor, cleanup) = installRecordingMonitor()
        defer { cleanup() }

        TextActionsSettings.setEnabled(true)
        #expect(monitor.isMonitoring)
        #expect(monitor.startCount == 1)

        TextActionsSettings.setEnabled(false)
        #expect(!monitor.isMonitoring, "关闭功能后不得继续监听选区（#303 路径 A）")
        #expect(monitor.stopCount == 1)
    }

    @Test("停用插件会停止由设置开关启动的同一个监听")
    func pluginDisableStopsMonitorStartedByToggle() async throws {
        let (monitor, cleanup) = installRecordingMonitor()
        defer { cleanup() }

        // 设置开关与插件注入同一个监听替身，模拟生产中二者共用单例。
        let plugin = TextActionsPlugin(selectionMonitor: monitor, isFeatureEnabled: { true })

        TextActionsSettings.setEnabled(true)
        #expect(monitor.isMonitoring)

        try await plugin.onDisable(kernel: KernelCoreContainer())
        #expect(!monitor.isMonitoring, "停用插件后不得残留设置开关启动的监听（#303 路径 B）")
        #expect(monitor.stopCount == 1)
    }

    // MARK: - Helpers

    /// 注入临时存储目录与监听替身。
    ///
    /// `TextActionsSettings.setEnabled` 会写 `TextActionsPluginLocalStore.shared`，
    /// 后者首次访问即读取运行时目录；测试进程必须先注入临时目录，否则触发
    /// 隔离守卫（不得读写本机真实数据目录）。
    private func installRecordingMonitor() -> (RecordingSelectionMonitor, () -> Void) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TextActionsCleanup-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        TextActionsRuntime.configure(settingsDirectory: directory)

        let monitor = RecordingSelectionMonitor()
        let previous = TextActionsSettings.selectionMonitor
        TextActionsSettings.selectionMonitor = monitor
        return (monitor, {
            TextActionsSettings.selectionMonitor = previous
            TextActionsRuntime.reset()
        })
    }
}

// MARK: - 测试替身

/// 记录启停调用的选区监听替身；不注册真实全局监听，也不读辅助功能授权。
@MainActor
private final class RecordingSelectionMonitor: TextSelectionMonitoring {
    private(set) var startCount = 0
    private(set) var stopCount = 0
    private(set) var isMonitoring = false

    func startMonitoring() {
        startCount += 1
        isMonitoring = true
    }

    func stopMonitoring() {
        stopCount += 1
        isMonitoring = false
    }
}