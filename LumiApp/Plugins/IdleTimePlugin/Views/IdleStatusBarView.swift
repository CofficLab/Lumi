import SwiftUI

struct IdleStatusBarView: View {
    @EnvironmentObject private var projectVM: ProjectVM
    @State private var snapshot: IdleInferenceSnapshot?

    var body: some View {
        Group {
            if !projectVM.currentProjectPath.isEmpty {
                StatusBarHoverContainer(
                    detailView: IdlePopoverView(snapshot: snapshot),
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
        .onAppear {
            refresh()
        }
        .onChange(of: projectVM.currentProjectPath) { _, _ in
            refresh()
        }
        .onApplicationDidBecomeActive {
            refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: .idleTimeSnapshotDidChange)) { _ in
            refresh()
        }
    }

    private var compactLabel: String {
        guard let window = snapshot?.restWindow else {
            return String(localized: "Idle learning", table: "IdleTime")
        }

        let label = IdleConfidenceLabel.label(for: window.confidence, source: window.source)
        switch label {
        case .learning:
            return String(localized: "Idle learning", table: "IdleTime")
        case .medium:
            return "\(String(localized: "Idle", table: "IdleTime")) ~\(formatWindow(window))"
        case .high:
            return "\(String(localized: "Idle", table: "IdleTime")) \(formatWindow(window))"
        }
    }

    private func refresh() {
        Task {
            let next = await IdleTimeService.shared.currentSnapshot()
            await MainActor.run {
                snapshot = next
            }
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
