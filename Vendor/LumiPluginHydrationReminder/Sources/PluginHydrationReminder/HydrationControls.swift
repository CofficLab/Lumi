import LumiUI
import SwiftUI

struct HydrationReminderControls: View {
    @ObservedObject private var manager = HydrationReminderManager.shared

    // 显式声明翻译key以防止Xcode构建时删除
    private static let startButtonTitle = String(localized: "Start", table: "HydrationReminder", bundle: .module)
    private static let stopButtonTitle = String(localized: "Stop", table: "HydrationReminder", bundle: .module)

    var body: some View {
        HStack(spacing: 8) {
            AppButton(
                manager.isActive ? Self.stopButtonTitle : Self.startButtonTitle,
                systemImage: manager.isActive ? "stop.fill" : "play.fill",
                style: manager.isActive ? .destructive : .primary,
                size: .small
            ) {
                if manager.isActive { manager.stop() } else { manager.start() }
            }
        }
    }
}
