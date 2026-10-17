import LumiUI
import SwiftUI

/// Daily token consumption trend shown under the 30-day activity heatmap.
///
/// Split out from `ActivityFooterView` per the project's one-view-per-file rule.
/// The chart is only meaningful once there are tokens to plot: a flat zero line
/// reads as a broken widget, so the caller omits this view entirely when
/// ``EmptyStateActivityViewModel/hasTokenActivity`` is false.
struct ActivityTokenTrendView: View {
    @LumiTheme private var theme
    let model: EmptyStateActivityViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            AppLineChart(
                points: model.tokenDays.map {
                    AppLineChartPoint(date: $0.date, value: Double($0.count))
                },
                accessibilityLabel: pluginLocalization.string("Daily token consumption chart"),
                valueLabel: { Self.compactTokenCount(Int($0)) }
            )
            .frame(height: 110)

            Text(summaryText)
                .font(.appCaption)
                .foregroundStyle(.tertiary)
                .monospacedDigit()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(summaryText))
    }

    /// "128.4K tokens in the last 30 days", matching the phrasing of the
    /// message strip above so the two read as one sentence pair.
    private var summaryText: String {
        let format = String(
            localized: "%@ tokens in the last %lld days",
            bundle: .module
        )
        return String(
            format: format,
            locale: pluginLocalization.preferredLocale(),
            Self.compactTokenCount(model.totalTokens ?? 0),
            EmptyStateActivityViewModel.windowDayCount
        )
    }

    /// Shortens a token count so the caption stays one line at any magnitude.
    ///
    /// A local copy rather than reusing the activity-heatmap plugin's formatter:
    /// that type lives in another plugin and plugins must not depend on each
    /// other (see the kernel/plugin boundary rule).
    ///
    /// - Important: `nonisolated` so tests can assert the thresholds without
    ///   hopping to the main actor — this is pure string formatting with no
    ///   UI state involved.
    nonisolated static func compactTokenCount(_ value: Int) -> String {
        let thresholds: [(limit: Double, suffix: String)] = [
            (1_000_000_000, "B"),
            (1_000_000, "M"),
            (1_000, "K"),
        ]
        for (limit, suffix) in thresholds where Double(value) >= limit {
            let scaled = Double(value) / limit
            // One decimal below 100 keeps "1.2M" readable; above it the
            // decimal is noise, so it is dropped ("150K", not "150.0K").
            let digits = scaled < 100 ? 1 : 0
            return String(format: "%.\(digits)f%@", scaled, suffix)
        }
        return String(value)
    }
}

// MARK: - 预览

/// Deterministic token series shaped like a real usage rhythm: a weekly cycle
/// with a heavier day, which is what makes a trend line worth drawing at all.
@MainActor
private enum TokenTrendPreview {
    static func sampleModel() -> EmptyStateActivityViewModel {
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.startOfDay(for: .now)
        let start = calendar.date(byAdding: .day, value: -29, to: today) ?? today

        var counts: [Date: Int] = [:]
        for offset in 0..<30 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
            let weekday = calendar.component(.weekday, from: day)
            let isWeekend = weekday == 1 || weekday == 7
            counts[day] = isWeekend ? offset % 4 : 1_200 + (offset * 977) % 26_000
        }

        let model = EmptyStateActivityViewModel(
            messages: nil,
            calendar: calendar,
            seededDays: EmptyStateActivityViewModel.makeDays(
                counts: counts,
                startDate: start,
                endDate: today,
                calendar: calendar
            ),
            seededTokenDays: EmptyStateActivityViewModel.makeTokenDays(
                counts: counts,
                startDate: start,
                endDate: today,
                calendar: calendar
            )
        )
        return model
    }
}

#Preview("Token trend") {
    ActivityTokenTrendView(model: TokenTrendPreview.sampleModel())
        .padding(24)
        .frame(width: 620)
}
