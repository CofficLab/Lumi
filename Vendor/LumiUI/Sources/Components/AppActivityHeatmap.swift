import SwiftUI

/// One day's activity for an `AppActivityHeatmap`.
///
/// Use level zero for no activity. Other levels map to higher activity; by
/// default the view expects levels from zero through `levelCount - 1`.
public struct AppActivityHeatmapDay: Identifiable, Equatable, Sendable {
    public let date: Date
    public let level: Int
    public let accessibilityLabel: String?

    public var id: Date { date }

    public init(date: Date, level: Int, accessibilityLabel: String? = nil) {
        self.date = date
        self.level = level
        self.accessibilityLabel = accessibilityLabel
    }
}

/// A calendar grid for daily activity, such as commits or usage events.
///
/// Supply one day per date and map product-specific counts to a level before
/// constructing the view. Missing dates are rendered as zero activity. The
/// component owns calendar layout and theme colors; data aggregation and
/// summaries stay with the calling feature.
public struct AppActivityHeatmap: View {
    @LumiTheme private var theme

    private let visibleStartDate: Date
    private let visibleEndDate: Date
    private let calendar: Calendar
    private let daysByDate: [Date: AppActivityHeatmapDay]
    private let weeks: [[Date]]
    private let weekMonthLabels: [String]
    private let cellSize: CGFloat
    private let cellSpacing: CGFloat
    private let levelCount: Int
    private let levelColors: [Color]?
    private let showsMonthLabels: Bool
    private let showsWeekdayLabels: Bool
    private let scrollsHorizontally: Bool
    private let showsLegend: Bool
    private let lessLabel: Text
    private let moreLabel: Text

    public init(
        days: [AppActivityHeatmapDay],
        range: ClosedRange<Date>,
        calendar: Calendar = .current,
        cellSize: CGFloat = 10,
        cellSpacing: CGFloat = 3,
        levelCount: Int = 5,
        levelColors: [Color]? = nil,
        showsMonthLabels: Bool = true,
        showsWeekdayLabels: Bool = false,
        scrollsHorizontally: Bool = true,
        showsLegend: Bool = false,
        lessLabel: Text = Text("Less"),
        moreLabel: Text = Text("More")
    ) {
        let visibleStartDate = calendar.startOfDay(for: range.lowerBound)
        let visibleEndDate = calendar.startOfDay(for: range.upperBound)
        let firstWeek = calendar.dateInterval(of: .weekOfYear, for: visibleStartDate)?.start ?? visibleStartDate
        let lastWeek = calendar.dateInterval(of: .weekOfYear, for: visibleEndDate)?.start ?? visibleEndDate
        let dayDistance = calendar.dateComponents([.day], from: firstWeek, to: lastWeek).day ?? 0
        let weekCount = max(dayDistance / 7, 0) + 1

        self.visibleStartDate = visibleStartDate
        self.visibleEndDate = visibleEndDate
        self.calendar = calendar
        self.daysByDate = Dictionary(
            days.map { (calendar.startOfDay(for: $0.date), $0) },
            uniquingKeysWith: { _, latest in latest }
        )
        let weekStarts = (0..<weekCount).compactMap {
            calendar.date(byAdding: .weekOfYear, value: $0, to: firstWeek)
        }
        let weeks = weekStarts.map { start in
            (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
        }
        self.weeks = weeks
        var previousMonth: Int?
        self.weekMonthLabels = weeks.map { week in
            guard let firstVisibleDay = week.first(where: { $0 >= visibleStartDate && $0 <= visibleEndDate }) else {
                return ""
            }
            let month = calendar.component(.month, from: firstVisibleDay)
            defer { previousMonth = month }
            guard month != previousMonth else { return "" }
            let symbols = calendar.shortMonthSymbols
            return symbols.indices.contains(month - 1) ? symbols[month - 1] : ""
        }
        self.cellSize = cellSize
        self.cellSpacing = cellSpacing
        self.levelCount = max(levelCount, 2)
        self.levelColors = levelColors
        self.showsMonthLabels = showsMonthLabels
        self.showsWeekdayLabels = showsWeekdayLabels
        self.scrollsHorizontally = scrollsHorizontally
        self.showsLegend = showsLegend
        self.lessLabel = lessLabel
        self.moreLabel = moreLabel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: cellSpacing) {
            Group {
                if scrollsHorizontally {
                    ScrollView(.horizontal, showsIndicators: false) {
                        heatmapContent
                    }
                } else {
                    heatmapContent
                }
            }
            if showsLegend {
                legend
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var heatmapContent: some View {
        HStack(alignment: .top, spacing: cellSpacing) {
            if showsWeekdayLabels {
                weekdayLabels
            }

            VStack(alignment: .leading, spacing: cellSpacing) {
                if showsMonthLabels {
                    monthLabels
                }

                HStack(alignment: .top, spacing: cellSpacing) {
                    ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                        VStack(spacing: cellSpacing) {
                            ForEach(Array(week.enumerated()), id: \.offset) { _, date in
                                dayCell(for: date)
                            }
                        }
                    }
                }
            }
        }
    }

    private var weekdayLabels: some View {
        let weekdays = calendar.veryShortStandaloneWeekdaySymbols
        return VStack(alignment: .trailing, spacing: cellSpacing) {
            if showsMonthLabels {
                Color.clear.frame(width: 16, height: 12)
            }
            ForEach(0..<7, id: \.self) { offset in
                let weekday = ((calendar.firstWeekday - 1 + offset) % 7)
                Text(weekdays[weekday])
                    .font(.system(size: 8))
                    .foregroundStyle(theme.textTertiary)
                    .frame(width: 16, height: cellSize, alignment: .trailing)
            }
        }
    }

    private var monthLabels: some View {
        return HStack(alignment: .firstTextBaseline, spacing: cellSpacing) {
            ForEach(Array(weekMonthLabels.enumerated()), id: \.offset) { _, label in
                Text(label)
                    .font(.system(size: 8))
                    .foregroundStyle(theme.textTertiary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(width: cellSize, height: 12, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private func dayCell(for date: Date) -> some View {
        let normalizedDate = calendar.startOfDay(for: date)
        if isVisible(normalizedDate), let day = daysByDate[normalizedDate] {
            let label = day.accessibilityLabel ?? defaultAccessibilityLabel(for: day)
            RoundedRectangle(cornerRadius: max(1, cellSize * 0.2), style: .continuous)
                .fill(color(for: day.level))
                .frame(width: cellSize, height: cellSize)
                .help(label)
                .accessibilityLabel(Text(label))
        } else if isVisible(normalizedDate) {
            RoundedRectangle(cornerRadius: max(1, cellSize * 0.2), style: .continuous)
                .fill(color(for: 0))
                .frame(width: cellSize, height: cellSize)
                .help(defaultAccessibilityLabel(for: normalizedDate, level: 0))
                .accessibilityLabel(Text(defaultAccessibilityLabel(for: normalizedDate, level: 0)))
        } else {
            Color.clear
                .frame(width: cellSize, height: cellSize)
                .accessibilityHidden(true)
        }
    }

    private var legend: some View {
        HStack(spacing: cellSpacing) {
            lessLabel
            ForEach(0..<resolvedLevelCount, id: \.self) { level in
                RoundedRectangle(cornerRadius: max(1, cellSize * 0.2), style: .continuous)
                    .fill(color(for: level))
                    .frame(width: cellSize, height: cellSize)
                    .accessibilityHidden(true)
            }
            moreLabel
        }
        .font(.system(size: 9))
        .foregroundStyle(theme.textTertiary)
    }

    private func color(for level: Int) -> Color {
        if let levelColors, !levelColors.isEmpty {
            return levelColors[min(max(level, 0), levelColors.count - 1)]
        }
        let normalizedLevel = min(max(level, 0), levelCount - 1)
        let opacity = normalizedLevel == 0 ? 0.08 : 0.2 + 0.8 * Double(normalizedLevel) / Double(levelCount - 1)
        return theme.primary.opacity(opacity)
    }

    private var resolvedLevelCount: Int {
        guard let levelColors, !levelColors.isEmpty else { return levelCount }
        return levelColors.count
    }

    private func defaultAccessibilityLabel(for day: AppActivityHeatmapDay) -> String {
        defaultAccessibilityLabel(for: day.date, level: day.level)
    }

    private func defaultAccessibilityLabel(for date: Date, level: Int) -> String {
        String.localizedStringWithFormat(
            LumiUILocalization.string("Activity on %@: level %lld"),
            date.formatted(date: .long, time: .omitted),
            Int64(level)
        )
    }

    private func isVisible(_ date: Date) -> Bool {
        date >= visibleStartDate && date <= visibleEndDate
    }
}

#Preview("Activity heatmap") {
    let calendar = Calendar(identifier: .gregorian)
    let endDate = calendar.startOfDay(for: .now)
    let startDate = calendar.date(byAdding: .day, value: -180, to: endDate) ?? endDate
    let days = (0...180).compactMap { offset -> AppActivityHeatmapDay? in
        guard let date = calendar.date(byAdding: .day, value: offset, to: startDate) else { return nil }
        return AppActivityHeatmapDay(
            date: date,
            level: (offset * 7 + offset / 3) % 5,
            accessibilityLabel: "\(date.formatted(date: .abbreviated, time: .omitted)), sample activity"
        )
    }

    AppActivityHeatmap(
        days: days,
        range: startDate...endDate,
        calendar: calendar,
        showsWeekdayLabels: true,
        showsLegend: true
    )
    .padding()
}
