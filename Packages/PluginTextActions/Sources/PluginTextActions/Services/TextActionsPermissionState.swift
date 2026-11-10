import AppKit
import Combine
import Foundation

/// 辅助功能权限在设置页的状态源。
///
/// ## 为什么需要独立的状态对象
///
/// 授权状态存在两个「外部变化」来源，二者都不会通知 SwiftUI：
///
/// 1. **用户点按钮请求权限**——系统弹窗异步出现，授权结果在用户切回
///    Lumi 之后才可读；
/// 2. **用户在系统设置里手动开关**——Lumi 完全不知情。
///
/// 唯一可靠的刷新时机是「应用重新变为活跃」。因此本对象订阅
/// `NSApplication.didBecomeActiveNotification`，每次激活都重新读取一次
/// 真实状态并递增 `revision`，让设置页据此重绘。
///
/// 模式与 `ComputerUseSettingsState` 一致。
@MainActor
final class TextActionsPermissionState: ObservableObject {
    /// 每次刷新递增，驱动视图重绘。
    @Published private(set) var revision = 0

    /// 当前辅助功能授权状态。
    private(set) var status: TextActionsPermissionService.Status = .notGranted

    /// 授权状态从「未授权」变为「已授权」时的回调。
    ///
    /// - Important: 通过注入而非在本对象内部直接读取插件开关。原因有二：
    ///   1. 「插件是否启用」与「权限状态」是两件事，不该耦合在视图层；
    ///   2. 读取开关会走 `TextActionsRuntime.settingsDirectory()`，而该目录
    ///      在测试进程里未注入会直接 `fatalError`。注入后单测无需准备
    ///      真实数据目录，也不会在开发者机器上误注册全局事件监听。
    var onPermissionGranted: (() -> Void)?

    /// 读取真实授权状态的入口。默认为系统查询，单测可注入以模拟
    /// 「用户离开应用去授权，再切回来」这次状态翻转。
    private let statusProvider: () -> TextActionsPermissionService.Status

    private var activationToken: NSObjectProtocol?

    init(statusProvider: @escaping () -> TextActionsPermissionService.Status = { TextActionsPermissionService.status }) {
        self.statusProvider = statusProvider
        refresh()
        activationToken = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    /// 停止监听应用激活事件。
    ///
    /// - Note: 不放在 `deinit` 里。Swift 6 的 `deinit` 是 nonisolated 的，
    ///   访问 `NSObjectProtocol`（非 Sendable）会直接编译失败。改为显式
    ///   停止，与 `ComputerUsePlugin` 的 `ApplicationActivationObserver`
    ///   保持同一套生命周期约定：由插件在 `onShutdown` 中调用。
    func stop() {
        if let activationToken {
            NotificationCenter.default.removeObserver(activationToken)
            self.activationToken = nil
        }
    }

    /// 重新读取真实授权状态。
    func refresh() {
        let wasGranted = status.isGranted
        status = statusProvider()
        revision &+= 1

        // 授权状态从「未授权」变为「已授权」时必须通知外部——否则用户明明
        // 在系统设置里打开了权限，划词功能却仍然不工作，且没有任何报错。
        guard !wasGranted, status.isGranted else { return }
        onPermissionGranted?()
    }

    /// 请求权限并刷新状态。
    ///
    /// 系统弹窗是异步的，此刻读到的多半仍是未授权；真正的状态会在用户
    /// 切回 Lumi 时由激活监听刷新。
    func request() {
        _ = TextActionsPermissionService.requestPermission()
        refresh()
    }

    /// 打开系统设置的辅助功能面板，并刷新状态。
    func openSystemSettings() {
        TextActionsPermissionService.openAccessibilitySettings()
        refresh()
    }
}
