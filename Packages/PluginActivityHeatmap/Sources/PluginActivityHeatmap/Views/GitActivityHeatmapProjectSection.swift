import Foundation
import LumiUI
import ProviderActivityHeatmap
import SwiftUI

/// GitHub-style commit activity rendered inside Settings → Projects.
struct GitActivityHeatmapProjectSection: View {
    let projectPath: String
    @ObservedObject private var viewModel: GitActivityHeatmapProjectViewModel
    @LumiTheme private var theme

    private let calendar: Calendar
    private let weekCount = 52
    private let cellSize: CGFloat = 10
    private let cellSpacing: CGFloat = 3

    init(projectPath: String, viewModel: GitActivityHeatmapProjectViewModel, calendar: Calendar = .current) {
        self.projectPath = projectPath
        self.viewModel = viewModel
        var calendar = calendar
        calendar.firstWeekday = 1
        self.calendar = calendar
    }

    var body: some View {
        AppSettingSection(
            title: L("Commit Activity"),
            titleAlignment: .leading
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(L("Commits in the last year"))
                        .font(.appCaption)
                        .foregroundStyle(theme.textSecondary)
                    Spacer()
                    if let snapshot = viewModel.snapshot {
                        Text(summary(for: snapshot))
                            .font(.appCaption)
                            .foregroundStyle(theme.textSecondary)
                    }
                    AppIconButton(systemImage: "arrow.clockwise") {
                        viewModel.refresh()
                    }
                    .help(L("Refresh activity"))
                }

                if viewModel.isLoading {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text(L("Loading commit activity…"))
                            .font(.appCaption)
                            .foregroundStyle(theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
                } else if let snapshot = viewModel.snapshot {
                    heatmap(snapshot)
                    legend
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.title3)
                            .foregroundStyle(theme.textTertiary)
                        Text(L("No Git commit activity available"))
                            .font(.appCaption)
                            .foregroundStyle(theme.textSecondary)
                        Text(L("Make sure this project is a Git repository."))
                            .font(.appMicro)
                            .foregroundStyle(theme.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
            }
        }
        .onChange(of: projectPath) { path in
            viewModel.update(projectPath: path)
        }
        .task(id: projectPath) {
            viewModel.refresh()
        }
    }

    private func heatmap(_ snapshot: ActivityHeatmapSnapshot) -> some View {
        let weeks = makeWeeks(snapshot: snapshot)
        return ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: cellSpacing) {
                    ForEach(weeks.indices, id: \.self) { index in
                        if index == 0 || monthChanged(at: index, in: weeks) {
                            Text(monthLabel(for: weeks[index].first?.date))
                                .font(.system(size: 9))
                                .foregroundStyle(theme.textTertiary)
                                .frame(width: cellSize, alignment: .leading)
                        } else {
                            Color.clear.frame(width: cellSize)
                        }
                    }
                }
                HStack(alignment: .top, spacing: cellSpacing) {
                    ForEach(weeks.indices, id: \.self) { index in
                        VStack(spacing: cellSpacing) {
                            ForEach(weeks[index]) { cell in
                                RoundedRectangle(cornerRadius: 2, style: .continuous)
                                    .fill(color(for: cell.commitCount, maximum: snapshot.days.map(\.commitCount).max() ?? 0))
                                    .frame(width: cellSize, height: cellSize)
                                    .help(accessibilityText(for: cell))
                                    .accessibilityLabel(accessibilityText(for: cell))
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var legend: some View {
        HStack(spacing: 5) {
            Text(L("Less"))
            ForEach(0..<5, id: \.self) { level in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(color(for: level, maximum: 4))
                    .frame(width: cellSize, height: cellSize)
            }
            Text(L("More"))
        }
        .font(.system(size: 9))
        .foregroundStyle(theme.textTertiary)
    }

    private struct HeatmapCell: Identifiable {
        let date: Date
        let commitCount: Int
        var id: Date { date }
    }

    /// 网格起点：当前周（周日）往前 weekCount-1 周；summary 与网格共用此窗口。
    nonisolated static func gridStart(calendar: Calendar, weekCount: Int, now: Date) -> Date {
        let today = calendar.startOfDay(for: now)
        let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        return calendar.date(byAdding: .weekOfYear, value: -(weekCount - 1), to: currentWeekStart) ?? currentWeekStart
    }

    /// 只统计可见网格窗口内的日期，避免把加载窗口里、网格之外的提交计入 summary。
    nonisolated static func visibleSummary(
        snapshot: ActivityHeatmapSnapshot,
        calendar: Calendar,
        weekCount: Int,
        now: Date
    ) -> (total: Int, activeDays: Int) {
        let start = gridStart(calendar: calendar, weekCount: weekCount, now: now)
        let end = calendar.date(byAdding: .day, value: weekCount * 7, to: start) ?? start
        var total = 0
        var activeDays = 0
        for day in snapshot.days {
            let date = calendar.startOfDay(for: day.date)
            guard date >= start, date < end else { continue }
            total += day.commitCount
            if day.commitCount > 0 { activeDays += 1 }
        }
        return (total, activeDays)
    }

    private func makeWeeks(snapshot: ActivityHeatmapSnapshot) -> [[HeatmapCell]] {
        let start = Self.gridStart(calendar: calendar, weekCount: weekCount, now: Date())
        let counts = Dictionary(uniqueKeysWithValues: snapshot.days.map {
            (calendar.startOfDay(for: $0.date), $0.commitCount)
        })
        return (0..<weekCount).map { week in
            (0..<7).map { weekday in
                let offset = week * 7 + weekday
                let date = calendar.date(byAdding: .day, value: offset, to: start) ?? start
                return HeatmapCell(date: date, commitCount: counts[date, default: 0])
            }
        }
    }

    private func monthChanged(at index: Int, in weeks: [[HeatmapCell]]) -> Bool {
        guard index > 0, let current = weeks[index].first?.date, let previous = weeks[index - 1].first?.date else { return false }
        return calendar.component(.month, from: current) != calendar.component(.month, from: previous)
    }

    private func monthLabel(for date: Date?) -> String {
        guard let date else { return "" }
        return date.formatted(.dateTime.month(.abbreviated))
    }

    private func color(for count: Int, maximum: Int) -> Color {
        guard count > 0 else { return theme.textTertiary.opacity(0.16) }
        let level = min(4, max(1, Int((Double(count) / Double(max(maximum, 1)) * 4).rounded(.up))))
        return theme.success.opacity(0.22 + Double(level) * 0.17)
    }

    private func summary(for snapshot: ActivityHeatmapSnapshot) -> String {
        let visible = Self.visibleSummary(snapshot: snapshot, calendar: calendar, weekCount: weekCount, now: Date())
        return String(format: L("%lld commits · %lld active days"), visible.total, visible.activeDays)
    }

    private func accessibilityText(for cell: HeatmapCell) -> String {
        String(format: L("%@ · %lld commits"), cell.date.formatted(date: .abbreviated, time: .omitted), cell.commitCount)
    }

    private func L(_ key: String) -> String {
        pluginLocalization.string(key)
    }
}
