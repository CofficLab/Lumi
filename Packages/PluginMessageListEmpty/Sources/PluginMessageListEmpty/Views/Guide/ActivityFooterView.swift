import Foundation
import LumiUI
import SwiftUI

/// A quiet activity strip pinned under the chat empty state.
///
/// The strip exists to give the empty state some substance: it reminds the
/// user that this workspace already has a history, without competing with the
/// title or the prompt suggestions. It renders nothing when there is no
/// activity, so a brand-new install keeps the clean composition it has today.
struct ActivityFooterView: View {
    @LumiTheme private var theme
    let model: EmptyStateActivityViewModel

    var body: some View {
        ZStack {
            // - Important: 这个 0 高度的透明占位**不可省略**。
            //
            //   `.task` 绑定在视图的生命周期上，而下面的 `if` 在首次渲染时
            //   一定为假（`totalMessages` 还是 `nil`，`hasActivity` 为 false）。
            //   若容器此刻是空的，SwiftUI 不会为该分支建立真实的 view
            //   identity，`.task` 于是**从不执行** —— 加载永远不会开始，
            //   `hasActivity` 永远保持 false，构成死锁。表现为：明明有历史
            //   数据，活动条却始终不出现。
            //
            //   实测证据：加日志后 `body` 求值多次而 `loadIfNeeded` 零次执行。
            //   一个 0 高度、透明的真实视图让 `.task` 有可挂载的载体。
            Color.clear
                .frame(height: 0)
                .allowsHitTesting(false)

            if model.hasActivity, let range = model.visibleRange {
                content(range: range)
            }
        }
        .task {
            await model.loadIfNeeded()
        }
    }

    private func content(range: ClosedRange<Date>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            AppActivityHeatmap(
                days: model.days.map {
                    AppActivityHeatmapDay(
                        date: $0.date,
                        level: $0.level,
                        accessibilityLabel: $0.accessibilityLabel
                    )
                },
                range: range,
                cellSize: 9,
                cellSpacing: 3,
                levelCount: 5,
                showsMonthLabels: false,
                showsWeekdayLabels: false,
                scrollsHorizontally: false,
                showsLegend: false
            )
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(summaryText)
                .font(.appCaption)
                .foregroundStyle(theme.textTertiary)

            // The trend is nested under the strip so the two share one x-axis
            // range and read as a single block. Each part hides itself when its
            // own series is empty, so a user with messages but no recorded
            // tokens still gets the heatmap without a dead chart.
            if model.hasTokenActivity {
                ActivityTokenTrendView(model: model)
                    .padding(.top, 6)
            }
        }
        .padding(.top, 18)
        .frame(maxWidth: 620)
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier(MessageListEmptyAccessibility.activityStripID)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(summaryText))
    }

    /// "62 messages in the last 30 days", phrased so the number reads as a
    /// reward for past work rather than as a metric to judge.
    ///
    /// Lookup and formatting are two steps because `String(localized:)`
    /// resolves the template from the module bundle but takes no format
    /// arguments, while `pluginLocalization.string` resolves a key without
    /// offering a formatting overload.
    private var summaryText: String {
        let format = String(
            localized: "%lld messages in the last %lld days",
            bundle: .module
        )
        return String(
            format: format,
            locale: pluginLocalization.preferredLocale(),
            model.totalMessages ?? 0,
            EmptyStateActivityViewModel.windowDayCount
        )
    }
}

// MARK: - 预览

/// Deterministic sample window for previews, shaped like a real user's rhythm:
/// steady on weekdays, quiet at the start of the window and on weekends.
@MainActor
private enum ActivityFooterPreview {
    static func sampleModel() -> EmptyStateActivityViewModel {
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.startOfDay(for: .now)
        let start = calendar.date(byAdding: .day, value: -29, to: today) ?? today

        var counts: [Date: Int] = [:]
        for offset in 0..<30 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
            let weekday = calendar.component(.weekday, from: day)
            let isWeekend = weekday == 1 || weekday == 7
            counts[day] = isWeekend ? offset % 3 : 2 + (offset * 7) % 11
        }

        return EmptyStateActivityViewModel(
            messages: nil,
            calendar: calendar,
            seededDays: EmptyStateActivityViewModel.makeDays(
                counts: counts,
                startDate: start,
                endDate: today,
                calendar: calendar
            )
        )
    }
}

#Preview("Activity footer") {
    ActivityFooterView(model: ActivityFooterPreview.sampleModel())
        .padding(24)
        .frame(width: 620)
}

#Preview("Activity footer — empty history") {
    ActivityFooterView(
        model: EmptyStateActivityViewModel(
            messages: nil,
            calendar: Calendar(identifier: .gregorian),
            seededDays: []
        )
    )
    .padding(24)
    .frame(width: 620)
}
