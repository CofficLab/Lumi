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
    let model: EmptyStateActivityViewModel

    /// Width the strip last received from its slot.
    ///
    /// Needed only to pick between the side-by-side and the stacked layout:
    /// `AppLineChart` is built on a `GeometryReader`, so it happily shrinks to
    /// any width. `ViewThatFits` therefore cannot detect "too narrow" here —
    /// the flexible child always reports that it fits — and an explicit
    /// measurement is what makes the fallback real.
    @State private var availableWidth: CGFloat = 0

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
        .background(alignment: .topLeading) { widthReader }
        .task {
            await model.loadIfNeeded()
        }
    }

    private func content(range: ClosedRange<Date>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if placesTrendBesideHeatmap {
                // 并排时两块在竖直方向居中：热力图窄而矮，折线图更高也更宽，
                // 居中对齐让整条活动条读起来是一个整体而不是两个控件。
                HStack(alignment: .center, spacing: ActivityFooterLayout.columnSpacing) {
                    heatmap(range: range)
                    trendView
                }
            } else {
                heatmap(range: range)
                if model.hasTokenActivity {
                    trendView
                        .padding(.top, 6)
                }
            }
        }
        .padding(.top, 18)
        .frame(maxWidth: 620)
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier(MessageListEmptyAccessibility.activityStripID)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(summaryText))
    }

    private func heatmap(range: ClosedRange<Date>) -> some View {
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
    }

    private var trendView: some View {
        ActivityTokenTrendView(model: model)
    }

    /// Reads the width the slot gives the strip without contributing any
    /// layout of its own: a background `GeometryReader` takes the size of the
    /// view it is attached to and is invisible to accessibility.
    private var widthReader: some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear { availableWidth = proxy.size.width }
                .onChange(of: proxy.size.width) { _, width in availableWidth = width }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// 只有「有 token 趋势」且「宽度够」两件事同时成立才并排，否则保持上下排布。
    private var placesTrendBesideHeatmap: Bool {
        model.hasTokenActivity
            && ActivityFooterLayout.usesSideBySideLayout(availableWidth: availableWidth)
    }

    /// "62 messages in the last 30 days", phrased so the number reads as a
    /// reward for past work rather than as a metric to judge.
    ///
    /// Not drawn any more — the strip shows only the two charts — but kept as
    /// the strip's accessibility label so the message total is still announced.
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

/// 活动条两块图的排布判定。
///
/// 抽成纯几何，让「多宽才并排」这条阈值可以被单测钉住：SwiftUI 里没有
/// 稳定可测的横向自适应 API（见 `ActivityFooterView.availableWidth` 的注释），
/// 所以阈值本身就是需要保护的契约。
enum ActivityFooterLayout {
    /// 30 天窗口最多铺满 6 周；`cellSize` 9 + `cellSpacing` 3 时约 72pt。
    static let heatmapWidth: CGFloat = 72
    /// 并排时两块之间的间距。
    static let columnSpacing: CGFloat = 18
    /// 折线图再窄就会把 30 个采样点挤成一团（点直径 6pt，间距不足 10pt 时
    /// 曲线会糊成一条粗线），此时宁可上下排布。
    static let minChartWidth: CGFloat = 300

    /// 并排所需的最小可用宽度。
    static var sideBySideMinWidth: CGFloat {
        heatmapWidth + columnSpacing + minChartWidth
    }

    static func usesSideBySideLayout(availableWidth: CGFloat) -> Bool {
        availableWidth >= sideBySideMinWidth
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
            ),
            seededTokenDays: EmptyStateActivityViewModel.makeTokenDays(
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

#Preview("Activity footer — narrow") {
    ActivityFooterView(model: ActivityFooterPreview.sampleModel())
        .padding(24)
        .frame(width: 280)
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
