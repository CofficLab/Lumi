import SwiftUI

struct IdleStatusBarView: View {
    @EnvironmentObject private var idleTimeVM: IdleTimeVM
    @EnvironmentObject private var projectVM: ProjectVM

    var body: some View {
        Group {
            if !projectVM.currentProjectPath.isEmpty {
                StatusBarHoverContainer(
                    detailView: IdlePopoverView(snapshot: idleTimeVM.snapshot),
                    popoverWidth: 480,
                    id: "idle-time-status"
                ) {
                    HStack(spacing: 6) {
                        Image(systemName: "moon.zzz")
                            .font(.system(size: 10))
                        Text(compactLabel)
                            .font(.system(size: 11))
                            .lineLimit(1)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var compactLabel: String {
        let label = idleTimeVM.confidenceLabel
        switch label {
        case .learning:
            return String(localized: "Idle learning", table: "IdleTime")
        case .medium:
            if let window = idleTimeVM.restWindow {
                return "\(String(localized: "Idle", table: "IdleTime")) ~\(formatWindow(window))"
            }
            return String(localized: "Idle learning", table: "IdleTime")
        case .high:
            if let window = idleTimeVM.restWindow {
                return "\(String(localized: "Idle", table: "IdleTime")) \(formatWindow(window))"
            }
            return String(localized: "Idle learning", table: "IdleTime")
        }
    }

    private func formatWindow(_ window: RestWindow) -> String {
        "\(formatMinute(window.startMinuteOfDay))-\(formatMinute(window.endMinuteOfDay))"
    }

    private func formatMinute(_ minuteOfDay: Int) -> String {
        let hour = minuteOfDay / 60
        let minute = minuteOfDay % 60
        return String(format: "%02d:%02d", hour, minute)
    }
}
