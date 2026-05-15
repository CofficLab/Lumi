import SwiftUI

struct IdlePopoverView: View {
    let snapshot: IdleInferenceSnapshot?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            Divider()
            metrics
            ActivityHeatStripView(scores: snapshot?.bucketScores ?? [])
        }
        .padding(16)
        .frame(width: 480, alignment: .leading)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Idle Time")
                    .font(.headline)
                    .foregroundColor(primaryTextColor)
                Text(windowText)
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundColor(primaryTextColor)
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
            metricRow("Coverage", coverageText)
            metricRow("Events", "\(snapshot?.eventCount ?? 0)")
            metricRow("Last active", lastActiveText)
            metricRow("Source", sourceText)
            metricRow("Confidence", confidencePercentText)
        }
        .font(.system(size: 12))
    }

    private func metricRow(_ title: String, _ value: String) -> some View {
        GridRow {
            Text(title)
                .foregroundColor(secondaryTextColor)
            Text(value)
                .foregroundColor(primaryTextColor)
                .monospacedDigit()
        }
    }

    private var windowText: String {
        guard let window = snapshot?.restWindow else { return "Learning" }
        let label = IdleConfidenceLabel.label(for: window.confidence, source: window.source)
        if label == .learning {
            return "Learning"
        }
        return "\(formatMinute(window.startMinuteOfDay)) - \(formatMinute(window.endMinuteOfDay))"
    }

    private var confidenceText: String {
        guard let window = snapshot?.restWindow else { return "Learning" }
        switch IdleConfidenceLabel.label(for: window.confidence, source: window.source) {
        case .learning:
            return "Learning"
        case .medium:
            return "Medium"
        case .high:
            return "High"
        }
    }

    private var confidenceColor: Color {
        guard let window = snapshot?.restWindow else { return secondaryTextColor }
        switch IdleConfidenceLabel.label(for: window.confidence, source: window.source) {
        case .learning:
            return secondaryTextColor
        case .medium:
            return .orange
        case .high:
            return .green
        }
    }

    private var coverageText: String {
        "\(snapshot?.observedDayCount ?? 0) / 28 days"
    }

    private var lastActiveText: String {
        guard let date = snapshot?.lastActivityAt else { return "None" }
        return Self.relativeFormatter.localizedString(for: date, relativeTo: Date())
    }

    private var sourceText: String {
        guard let source = snapshot?.restWindow?.source else { return "Learning" }
        switch source {
        case .weekday:
            return "Weekday model"
        case .weekend:
            return "Weekend model"
        case .globalFallback:
            return "Global model"
        case .defaultFallback:
            return "Default fallback"
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

    private var primaryTextColor: Color {
        Color.adaptive(light: "1C1C1E", dark: "FFFFFF")
    }

    private var secondaryTextColor: Color {
        Color.adaptive(light: "6B6B7B", dark: "EBEBF5")
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()
}
