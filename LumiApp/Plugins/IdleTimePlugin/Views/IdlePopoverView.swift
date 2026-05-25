import SwiftUI
import LumiUI

struct IdlePopoverView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    let snapshot: IdleInferenceSnapshot?

    var body: some View {
        StatusBarPopoverScaffold(
            title: String(localized: "Idle Time", table: "IdleTime"),
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
            metricRow(String(localized: "Coverage", table: "IdleTime"), coverageText)
            metricRow(String(localized: "Events", table: "IdleTime"), "\(snapshot?.eventCount ?? 0)")
            metricRow(String(localized: "Last active", table: "IdleTime"), lastActiveText)
            metricRow(String(localized: "Source", table: "IdleTime"), sourceText)
            metricRow(String(localized: "Confidence", table: "IdleTime"), confidencePercentText)
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
        guard let window = snapshot?.restWindow else { return String(localized: "Learning", table: "IdleTime") }
        let label = IdleConfidenceLabel.label(for: window.confidence, source: window.source)
        if label == .learning {
            return String(localized: "Learning", table: "IdleTime")
        }
        return "\(formatMinute(window.startMinuteOfDay)) - \(formatMinute(window.endMinuteOfDay))"
    }

    private var confidenceText: String {
        guard let window = snapshot?.restWindow else { return String(localized: "Learning", table: "IdleTime") }
        switch IdleConfidenceLabel.label(for: window.confidence, source: window.source) {
        case .learning:
            return String(localized: "Learning", table: "IdleTime")
        case .medium:
            return String(localized: "Medium", table: "IdleTime")
        case .high:
            return String(localized: "High", table: "IdleTime")
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
        return "\(count) / 28 \(String(localized: "days", table: "IdleTime"))"
    }

    private var lastActiveText: String {
        guard let date = snapshot?.lastActivityAt else { return String(localized: "None", table: "IdleTime") }
        return Self.relativeFormatter.localizedString(for: date, relativeTo: Date())
    }

    private var sourceText: String {
        guard let source = snapshot?.restWindow?.source else { return String(localized: "Learning", table: "IdleTime") }
        switch source {
        case .weekday:
            return String(localized: "Weekday model", table: "IdleTime")
        case .weekend:
            return String(localized: "Weekend model", table: "IdleTime")
        case .globalFallback:
            return String(localized: "Global model", table: "IdleTime")
        case .defaultFallback:
            return String(localized: "Default fallback", table: "IdleTime")
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
