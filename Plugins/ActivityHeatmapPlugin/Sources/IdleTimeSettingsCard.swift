import AppKit
import SwiftUI
import LumiKernel
import LumiUI

/// Idle-time settings and inference details live with the activity heatmap.
struct IdleTimeSettingsCard: View {
    let provider: (any IdleTimeProviding)?
    let dataDirectory: URL?
    @State private var snapshot: IdleInferenceSnapshot?

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label(LumiPluginLocalization.string("Idle Time", bundle: .module), systemImage: "moon.zzz")
                        .font(.appBodyEmphasized)
                    Spacer()
                    Text(LumiPluginLocalization.string("Activity patterns and rest windows", bundle: .module))
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                    if dataDirectory != nil {
                        AppButton(LumiPluginLocalization.string("Open Data Directory", bundle: .module), systemImage: "folder", size: .small) {
                            openDataDirectory()
                        }
                    }
                }

                if let snapshot {
                    HStack(spacing: 24) {
                        metric("Rest window", restWindowText(snapshot))
                        metric("Confidence", confidenceText(snapshot))
                        metric("Events", "\(snapshot.eventCount)")
                        metric("Active days", "\(snapshot.observedDayCount)")
                    }

                    scoreStrip(snapshot.bucketScores)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(16)
        }
        .task { await reload() }
        .onReceive(NotificationCenter.default.publisher(for: .idleTimeSnapshotDidChange)) { _ in
            Task { await reload() }
        }
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.appCaption).foregroundStyle(.secondary)
            Text(value).font(.appBodyEmphasized).monospacedDigit()
        }
    }

    private func scoreStrip(_ scores: [Double]) -> some View {
        let maximum = max(scores.max() ?? 0, 1)
        return HStack(alignment: .bottom, spacing: 2) {
            ForEach(Array(scores.enumerated()), id: \.offset) { _, score in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.accentColor.opacity(0.2 + 0.8 * (score / maximum)))
                    .frame(maxWidth: .infinity, minHeight: 4, maxHeight: 42 * CGFloat(score / maximum) + 4)
            }
        }
        .frame(height: 48, alignment: .bottom)
        .accessibilityLabel(LumiPluginLocalization.string("Activity intensity by time of day", bundle: .module))
    }

    private func restWindowText(_ snapshot: IdleInferenceSnapshot) -> String {
        guard let window = snapshot.restWindow,
              IdleConfidenceLabel.label(for: window.confidence, source: window.source) != .learning else {
            return LumiPluginLocalization.string("Learning", bundle: .module)
        }
        return "\(format(window.startMinuteOfDay)) – \(format(window.endMinuteOfDay))"
    }

    private func confidenceText(_ snapshot: IdleInferenceSnapshot) -> String {
        guard let window = snapshot.restWindow else {
            return LumiPluginLocalization.string("Learning", bundle: .module)
        }
        return "\(Int((window.confidence * 100).rounded()))%"
    }

    private func format(_ minute: Int) -> String {
        String(format: "%02d:%02d", minute / 60, minute % 60)
    }

    private func reload() async {
        guard let provider else { return }
        snapshot = await provider.currentSnapshot()
    }

    private func openDataDirectory() {
        guard let dataDirectory else { return }
        try? FileManager.default.createDirectory(at: dataDirectory, withIntermediateDirectories: true)
        _ = NSWorkspace.shared.open(dataDirectory)
    }
}
