import AppKit
import KitReminder
import SwiftUI

/// 喝水提醒的全屏遮罩。
///
/// 遮罩覆盖所有显示器（用外接大屏工作的用户正是最需要提醒的人），
/// 具体实现见 `ReminderOverlayController`。
///
/// ## 为什么要做成单例
///
/// 早期实现每次提醒都 `HydrationReminderOverlayWindow()` 新建一个临时对象，
/// 表达式求值完对象即被释放，其内部的控制器随之释放；
/// 控制器负责淡出关闭的延迟回调因此永远不会执行，
/// 全屏遮罩**永久滞留屏幕**，且因忽略鼠标事件而无法关闭。
///
/// 改为单例后，遮罩与它的控制器在整个 App 生命周期内都存活，
/// 淡出回调必定执行；同时 `dismissAll()` 能真正关掉当前这一块遮罩。
@MainActor
final class HydrationReminderOverlayWindow {
    /// 全局唯一的遮罩实例。
    static let shared = HydrationReminderOverlayWindow()

    private let controller = ReminderOverlayController {
        AnyView(HydrationGradientView())
    }

    private init() {}

    /// 在所有屏幕上显示遮罩，动画淡入后自动淡出。
    func showAndFadeOut() {
        controller.showAndFadeOut()
    }

    /// 立即关闭当前遮罩（停止提醒、卸载插件时调用）。
    func dismissAll() {
        controller.dismissAll()
    }
}

private struct HydrationGradientView: View {
    @State private var isAnimating = false
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.blue.opacity(0.3), Color.blue.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                    .scaleEffect(isAnimating ? 1.1 : 1.0)
                    .animation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isAnimating)
                Text(String(localized: "Hydration", table: "HydrationReminder", bundle: .module))
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)
                Text(String(localized: "Don't forget to drink some water!", table: "HydrationReminder", bundle: .module))
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .padding(40)
        }
        .onAppear { isAnimating = true }
    }
}
