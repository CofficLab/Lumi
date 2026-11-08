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
    private var windows: [NSWindow] = []

    /// 遮罩内容（由调用方提供，不同提醒有不同文案与配色）。
    private let content: () -> AnyView

    /// - Parameters:
    ///   - displayDuration: 保持显示时长（秒）。
    ///   - content: 遮罩内容视图工厂。
    public init(
        displayDuration: TimeInterval = 3.0,
        content: @escaping () -> AnyView
    ) {
        self.displayDuration = displayDuration
        self.content = content
    }

    /// 在所有屏幕上显示遮罩，动画淡入后自动淡出。
    public func showAndFadeOut() {
        dismissAll()

        let screens = NSScreen.screens
        guard !screens.isEmpty else { return }

        for screen in screens {
            let window = makeWindow(for: screen)
            windows.append(window)
        }

        for window in windows {
            window.alphaValue = 0
            window.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = fadeInDuration
                window.animator().alphaValue = 1.0
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + displayDuration) { [weak self] in
            self?.fadeOutAndClose()
        }
    }

    /// 立即关闭所有遮罩窗口。
    public func dismissAll() {
        for window in windows {
            window.orderOut(nil)
            window.close()
        }
        windows.removeAll()
    }

    private func makeWindow(for screen: NSScreen) -> NSWindow {
        let window = NSWindow(
            // 用 frame 而非 visibleFrame：遮罩应覆盖整块屏幕，包括 Dock 与菜单栏区域。
            contentRect: screen.frame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = windowLevel
        window.isReleasedWhenClosed = false
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.contentView = NSHostingView(rootView: content())

        return window
    }

    private func fadeOutAndClose() {
        let fading = windows
        windows.removeAll()

        for window in fading {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = fadeOutDuration
                context.completionHandler = {
                    window.orderOut(nil)
                    window.close()
                }
                window.animator().alphaValue = 0
            }
        }
    }
}
