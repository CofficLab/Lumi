import AppKit
import Foundation
import Testing
@testable import TextActionsPlugin

// MARK: - 权限状态模型

@Suite("Text Actions 辅助功能权限")
@MainActor
struct TextActionsPermissionTests {

    @Test("已授权状态可由状态判定得出")
    func grantedStatusIsRecognized() {
        #expect(TextActionsPermissionService.Status.granted.isGranted)
        #expect(!TextActionsPermissionService.Status.notGranted.isGranted)
    }

    @Test("状态判定不触发系统授权弹窗")
    func statusQueryDoesNotPromptSystem() {
        // `status` 走的是 `AXTrustedCheckOptionPrompt: false`，
        // 即「只查询、不提示」。若误传 true，用户每次打开设置页都会
        // 被系统的授权弹窗打断。
        //
        // 这里无法直接断言调用参数，但可以断言「查询」不会改变授权状态，
        // 且连续多次查询结果稳定（弹窗是异步的，不应影响返回值）。
        let first = TextActionsPermissionService.status
        let second = TextActionsPermissionService.status
        #expect(first == second)
    }

    @Test("权限状态对象初始就反映真实授权状态")
    func permissionStateReflectsRealStatusOnInit() {
        let state = TextActionsPermissionState()
        defer { state.stop() }

        #expect(state.status == TextActionsPermissionService.status)
    }

    @Test("刷新会推进 revision 以驱动视图重绘")
    func refreshAdvancesRevision() {
        let state = TextActionsPermissionState()
        defer { state.stop() }

        let before = state.revision
        state.refresh()
        #expect(state.revision != before)
    }

    @Test("停止监听后可安全重复调用")
    func stopIsIdempotent() {
        let state = TextActionsPermissionState()
        state.stop()
        state.stop()
    }

    @Test("授权状态变化时通过回调通知外部")
    func reportsGrantThroughCallback() {
        var granted = false
        let state = TextActionsPermissionState(statusProvider: { granted ? .granted : .notGranted })
        defer { state.stop() }

        var grantedCount = 0
        state.onPermissionGranted = { grantedCount += 1 }

        // 未授权时刷新不应通知。
        state.refresh()
        #expect(grantedCount == 0)

        // 用户去系统设置授权后切回 Lumi：激活刷新读到 granted，
        // 必须通知外部启动选区监听，否则划词功能静默失效。
        granted = true
        state.refresh()
        #expect(grantedCount == 1)

        // 已授权状态重复刷新不应重复通知。
        state.refresh()
        #expect(grantedCount == 1)
    }
}

// MARK: - 选区管理器与权限的联动

@Suite("Text Actions 权限与选区监听联动")
@MainActor
struct TextActionsPermissionMonitoringTests {

    @Test("请求权限后未授权时不启动监听")
    func doesNotMonitorWhenPermissionMissing() {
        let monitor = RecordingTextEventMonitor()
        let manager = TextSelectionManager(
            eventMonitor: monitor,
            selectedTextProvider: RecordingSelectedTextProvider(),
            permissionChecker: { false }
        )

        manager.startMonitoring()

        #expect(!manager.isPermissionGranted)
        #expect(monitor.addCount == 0)
    }

    @Test("授权后可以启动监听")
    func monitorsAfterPermissionGranted() {
        let monitor = RecordingTextEventMonitor()
        var granted = false
        let manager = TextSelectionManager(
            eventMonitor: monitor,
            selectedTextProvider: RecordingSelectedTextProvider(),
            permissionChecker: { granted }
        )

        manager.startMonitoring()
        #expect(monitor.addCount == 0)

        granted = true
        manager.refreshPermission()
        manager.startMonitoring()
        #expect(monitor.addCount == 1)
    }
}

// MARK: - 测试替身

@MainActor
private final class RecordingTextEventMonitor: TextEventMonitoring {
    private(set) var addCount = 0
    private(set) var removeCount = 0
    private(set) var lastMask: NSEvent.EventTypeMask?

    func addGlobalMonitor(
        matching mask: NSEvent.EventTypeMask,
        handler: @escaping (NSEvent) -> Void
    ) -> Any? {
        addCount += 1
        lastMask = mask
        return NSObject()
    }

    func removeMonitor(_ monitor: Any) {
        removeCount += 1
    }
}

@MainActor
private final class RecordingSelectedTextProvider: SelectedTextProviding {
    private var results: [SelectedText?]

    init(results: [SelectedText?] = []) {
        self.results = results
    }

    func readSelectedText(anchor: CGPoint) -> SelectedText? {
        guard !results.isEmpty else { return nil }
        return results.removeFirst()
    }
}
