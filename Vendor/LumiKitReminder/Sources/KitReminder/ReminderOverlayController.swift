import AppKit
import SwiftUI

/// 休息提醒的全屏遮罩。
///
/// 遮罩需要覆盖**所有显示器**——用外接大屏工作的用户正是最需要提醒的人，
/// 只盖住主屏等于没提醒。
///
/// 实现要点：
/// - 每块屏幕一个窗口，屏幕数量在提醒触发时才确定（用户可能随时插拔显示器）；
/// - 用 `screen.frame`（而不是 `visibleFrame`）覆盖整块屏幕，
///   遮罩才不会在 Dock 与菜单栏处缺一块；
/// - 屏幕之间可能有不同的缩放系数，窗口按各自屏幕的坐标系定位即可。
///
/// 三个提醒插件（护眼 / 喝水 / 拉伸）共用本组件，仅渐变配色不同。
///
/// ## 生命周期：为什么控制器必须自持有
///
/// 遮罩显示结束后需要延迟淡出，这个延迟回调**必须**在控制器还活着时执行。
/// 早期实现里，插件用临时对象创建控制器：
///
/// ```swift
/// HydrationReminderOverlayWindow().showAndFadeOut()
/// ```
///
/// 表达式求值完，临时对象立即释放，控制器随之释放；淡出回调里的
/// `self` 变成 nil，回调体永不执行——窗口停留在 `alphaValue == 1`，
/// 全屏遮罩**永久滞留屏幕**，且因 `ignoresMouseEvents` 无法点击关闭。
///
/// 这里用 `selfRetain` 在展示期间持有自己，直到淡出真正完成才释放，
/// 从根上消除「回调因 self 为 nil 而失效」这一类问题。
@MainActor
public final class ReminderOverlayController {
    /// 窗口的窗口级别：浮在普通应用之上。
    private let windowLevel: NSWindow.Level = .floating

    /// 淡入时长（秒）。
    private let fadeInDuration: TimeInterval = 0.5

    /// 保持显示时长（秒）。
    private let displayDuration: TimeInterval

    /// 淡出时长（秒）。
    private let fadeOutDuration: TimeInterval = 2.0

    /// 当前显示的窗口（每个屏幕一个）。
    private var windows: [ReminderOverlayWindowing] = []

    /// 展示期间对自身的强引用。
    ///
    /// 淡出回调通过弱引用访问控制器，靠这份强引用保证回调执行时
    /// 控制器仍然存活。淡出完成后立即释放。
    private var selfRetain: ReminderOverlayController?

    /// 待执行的淡出任务，用于「用户手动关闭」时取消自动淡出。
    private var pendingFadeOut: DispatchWorkItem?

    /// 窗口工厂：生产环境创建真实的 `NSPanel`，测试注入可控替身。
    private let windowFactory: @MainActor (@escaping @MainActor () -> Void) -> [ReminderOverlayWindowing]

    /// - Parameters:
    ///   - displayDuration: 保持显示时长（秒）。
    ///   - content: 遮罩内容视图工厂。
    public convenience init(
        displayDuration: TimeInterval = 3.0,
        content: @escaping () -> AnyView
    ) {
        self.init(
            displayDuration: displayDuration,
            windowFactory: { dismiss in
                ReminderOverlayController.makeScreenWindows(content: content, onDismiss: dismiss)
            }
        )
    }

    /// 指定窗口工厂的初始化入口。
    ///
    /// 单元测试用它注入替身窗口，从而在**无窗口进程**中验证时序逻辑
    /// （尤其是「淡出回调必定执行」这一条）。
    ///
    /// - Parameters:
    ///   - displayDuration: 保持显示时长（秒）。
    ///   - windowFactory: 窗口工厂，参数为「关闭全部遮罩」的回调。
    init(
        displayDuration: TimeInterval = 3.0,
        windowFactory: @escaping @MainActor (@escaping @MainActor () -> Void) -> [ReminderOverlayWindowing]
    ) {
        self.displayDuration = displayDuration
        self.windowFactory = windowFactory
    }

    /// 当前是否仍有遮罩在展示。
    public var isVisible: Bool {
        windows.contains { $0.isVisible }
    }

    /// 在所有屏幕上显示遮罩，动画淡入后自动淡出。
    public func showAndFadeOut() {
        closeWindows()
        cancelPendingFadeOut()

        let dismiss: @MainActor () -> Void = { [weak self] in
            self?.dismissAll()
        }
        let created = windowFactory(dismiss)
        guard !created.isEmpty else { return }

        windows = created
        // 自持有：淡出回调依赖控制器存活，见类型注释。
        selfRetain = self

        for window in windows {
            window.setAlpha(0, animated: false, duration: 0, completion: nil)
            window.show()
        }
        for window in windows {
            window.setAlpha(1, animated: true, duration: fadeInDuration, completion: nil)
        }

        scheduleFadeOut(after: displayDuration)
    }

    /// 立即关闭所有遮罩窗口。
    ///
    /// 用户手动关闭（点击 / Esc）、插件停止提醒时都会走这里。
    public func dismissAll() {
        cancelPendingFadeOut()
        closeWindows()
        selfRetain = nil
    }

    // MARK: - 私有

    /// 关闭并释放当前所有窗口。
    private func closeWindows() {
        for window in windows {
            window.hide()
            window.tearDown()
        }
        windows.removeAll()
    }

    /// 安排延迟淡出。
    ///
    /// 闭包用弱引用访问控制器：控制器在展示期间由 `selfRetain` 持有，
    /// 因此弱引用一定能解析成功。
    private func scheduleFadeOut(after delay: TimeInterval) {
        let item = DispatchWorkItem { [weak self] in
            self?.fadeOutAndClose()
        }
        pendingFadeOut = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    /// 取消尚未执行的淡出任务。
    private func cancelPendingFadeOut() {
        pendingFadeOut?.cancel()
        pendingFadeOut = nil
    }

    /// 淡出并关闭。
    private func fadeOutAndClose() {
        pendingFadeOut = nil

        let fading = windows
        windows.removeAll()

        for window in fading {
            window.setAlpha(0, animated: true, duration: fadeOutDuration) {
                window.hide()
                window.tearDown()
            }
        }

        // 淡出已发起，控制器不再需要自持有。
        selfRetain = nil
    }

    /// 为每块屏幕创建一个遮罩面板。
    private static func makeScreenWindows(
        content: @escaping () -> AnyView,
        onDismiss: @escaping @MainActor () -> Void
    ) -> [ReminderOverlayWindowing] {
        NSScreen.screens.map { screen in
            ReminderOverlayPanelWindow(screen: screen, content: content, onDismiss: onDismiss)
        }
    }
}
