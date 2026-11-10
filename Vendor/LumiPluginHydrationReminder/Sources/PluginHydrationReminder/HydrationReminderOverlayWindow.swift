import AppKit
import KitReminder
import SwiftUI

/// 喝水提醒的全屏遮罩。
///
/// 遮罩覆盖所有显示器（用外接大屏工作的用户正是最需要提醒的人），
/// 具体实现见 `ReminderOverlayController`。
@MainActor
class HydrationReminderOverlayWindow {
    private let controller = ReminderOverlayController {
        AnyView(HydrationGradientView())
    }

    /// 在所有屏幕上显示遮罩，动画淡入后自动淡出。
    func showAndFadeOut() {
        controller.showAndFadeOut()
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
