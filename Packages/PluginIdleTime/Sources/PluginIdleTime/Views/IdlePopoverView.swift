import LumiUI
import ProviderIdleTime
import SwiftUI

/// 休息窗口快照展示：窗口时间、置信度标签、指标网格与 24 小时活动热条。
///
/// 由旧版 `Plugins/IdleTimePlugin/Sources/Views/IdlePopoverView.swift` 迁移而来，
/// 依赖的 LumiUI 组件（StatusBarPopoverScaffold / GlassDivider / 字体）保持不变。
public struct IdlePopoverView: View {
    @LumiTheme private var theme: any LumiUITheme

    public let snapshot: IdleInferenceSnapshot?

    public var body: some View {
        StatusBarPopoverScaffold(
            title: L("Idle Time"),
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
            metricRow(L("Coverage"), coverageText)
            metricRow(L("Events"), "\(snapshot?.eventCount ?? 0)")
            metricRow(L("Last active"), lastActiveText)
            metricRow(L("Source"), sourceText)
            metricRow(L("Confidence"), confidencePercentText)
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
        guard let window = snapshot?.restWindow else { return L("Learning") }
        let label = IdleConfidenceLabel.label(for: window.confidence, source: window.source)
        if label == .learning {
            return L("Learning")
        }
        return "\(formatMinute(window.startMinuteOfDay)) - \(formatMinute(window.endMinuteOfDay))"
    }

    private var confidenceText: String {
        guard let window = snapshot?.restWindow else { return L("Learning") }
        switch IdleConfidenceLabel.label(for: window.confidence, source: window.source) {
        case .learning:
            return L("Learning")
        case .medium:
            return L("Medium")
        case .high:
            return L("High")
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
        return "\(count) / 28 \(L("days"))"
    }

    private var lastActiveText: String {
        guard let date = snapshot?.lastActivityAt else { return L("None") }
        return Self.relativeFormatter.localizedString(for: date, relativeTo: Date())
    }

    private var sourceText: String {
        guard let source = snapshot?.restWindow?.source else { return L("Learning") }
        switch source {
        case .weekday:
            return L("Weekday model")
        case .weekend:
            return L("Weekend model")
        case .globalFallback:
            return L("Global model")
        case .defaultFallback:
            return L("Default fallback")
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

    private func L(_ key: String) -> String {
        LumiPluginLocalization.string(key, bundle: .module)
    }
}
