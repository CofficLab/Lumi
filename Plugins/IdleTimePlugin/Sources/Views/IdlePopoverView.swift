import SwiftUI
import LumiUI

public struct IdlePopoverView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    public let snapshot: IdleInferenceSnapshot?

    public var body: some View {
        StatusBarPopoverScaffold(
            title: String(localized: "Idle Time", bundle: .module),
            systemImage: "moon.zzz",
            showsHeaderDivider: false
        ) {
            header
            GlassDivider()
            metrics
            ActivityHeatStripView(scores: snapshot?.bucketScores ?? [])
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 6) {
                Text(windowText)
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundColor(theme.textPrimary)
                    .monospacedDigit()
            }
            Spacer()
            Text(confidenceText)
                .font(.caption.weight(.semibold))
                .foregroundColor(confidenceColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(confidenceColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    private var metrics: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 18, verticalSpacing: 8) {
            metricRow(String(localized: "Coverage", bundle: .module), coverageText)
            metricRow(String(localized: "Events", bundle: .module), "\(snapshot?.eventCount ?? 0)")
            metricRow(String(localized: "Last active", bundle: .module), lastActiveText)
            metricRow(String(localized: "Source", bundle: .module), sourceText)
            metricRow(String(localized: "Confidence", bundle: .module), confidencePercentText)
        }
        .font(.appCaption)
    }

    private func metricRow(_ title: String, _ value: String) -> some View {
        GridRow {
            Text(title)
                .foregroundColor(theme.textSecondary)
            Text(value)
                .foregroundColor(theme.textPrimary)
                .monospacedDigit()
        }
    }

    private var windowText: String {
        guard let window = snapshot?.restWindow else { return String(localized: "Learning", bundle: .module) }
        let label = IdleConfidenceLabel.label(for: window.confidence, source: window.source)
        if label == .learning {
            return String(localized: "Learning", bundle: .module)
        }
        return "\(formatMinute(window.startMinuteOfDay)) - \(formatMinute(window.endMinuteOfDay))"
    }

    private var confidenceText: String {
        guard let window = snapshot?.restWindow else { return String(localized: "Learning", bundle: .module) }
        switch IdleConfidenceLabel.label(for: window.confidence, source: window.source) {
        case .learning:
            return String(localized: "Learning", bundle: .module)
        case .medium:
            return String(localized: "Medium", bundle: .module)
        case .high:
            return String(localized: "High", bundle: .module)
        }
    }

    private var confidenceColor: Color {
        guard let window = snapshot?.restWindow else { return theme.textSecondary }
        switch IdleConfidenceLabel.label(for: window.confidence, source: window.source) {
        case .learning:
            return theme.textSecondary
        case .medium:
            return theme.warning
        case .high:
            return theme.success
        }
    }

    private var coverageText: String {
        let count = snapshot?.observedDayCount ?? 0
        return "\(count) / 28 \(String(localized: "days", bundle: .module))"
    }

    private var lastActiveText: String {
        guard let date = snapshot?.lastActivityAt else { return String(localized: "None", bundle: .module) }
        return Self.relativeFormatter.localizedString(for: date, relativeTo: Date())
    }

    private var sourceText: String {
        guard let source = snapshot?.restWindow?.source else { return String(localized: "Learning", bundle: .module) }
        switch source {
        case .weekday:
            return String(localized: "Weekday model", bundle: .module)
        case .weekend:
            return String(localized: "Weekend model", bundle: .module)
        case .globalFallback:
            return String(localized: "Global model", bundle: .module)
        case .defaultFallback:
            return String(localized: "Default fallback", bundle: .module)
        }
    }

    private var confidencePercentText: String {
        guard let confidence = snapshot?.restWindow?.confidence else { return "0%" }
        return "\(Int((confidence * 100).rounded()))%"
    }

    private func formatMinute(_ minuteOfDay: Int) -> String {
        let hour = minuteOfDay / 60
        let minute = minuteOfDay % 60
        return String(format: "%02d:%02d", hour, minute)
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()
}
