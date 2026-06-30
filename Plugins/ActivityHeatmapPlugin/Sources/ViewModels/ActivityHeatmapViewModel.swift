import Foundation
import LumiCoreKit

/// Statistics period options for the heatmap view.
enum ActivityHeatmapPeriod: Int, CaseIterable, Identifiable {
    case days30 = 30
    case days90 = 90
    case year = 365

    var id: Int { rawValue }

    var localizedTitle: String {
        switch self {
        case .days30:
            LumiPluginLocalization.string("Last 30 days", bundle: .module)
        case .days90:
            LumiPluginLocalization.string("Last 90 days", bundle: .module)
        case .year:
            LumiPluginLocalization.string("Last year", bundle: .module)
        }
    }
}

/// View model that fetches message history and aggregates into a daily heatmap.
@MainActor
@Observable
final class ActivityHeatmapViewModel {
    // MARK: - Dependencies

    private let historyService: (any HistoryQueryService)?

    // MARK: - State

    private(set) var heatmapData: [ActivityDay] = []
    private(set) var isLoading = false
    var period: ActivityHeatmapPeriod = .year {
        didSet {
            Task { await load() }
        }
    }

    // MARK: - Init

    init(historyService: (any HistoryQueryService)?) {
        self.historyService = historyService
    }

    // MARK: - Load

    func load() async {
        guard let service = historyService else { return }
        isLoading = true
        defer { isLoading = false }

        let totalCount = await service.fetchMessageCount()
        guard totalCount > 0 else {
            heatmapData = []
            return
        }

        let allMessages = await paginateMessages(service, total: totalCount)

        // 聚合操作移到后台线程
        let days = period.rawValue
        let result = await Task.detached(priority: .userInitiated) {
            Self.aggregateByDay(allMessages, days: days)
        }.value

        heatmapData = result
    }

    // MARK: - Pagination

    private func paginateMessages(
        _ service: any HistoryQueryService,
        total: Int
    ) async -> [HistoryMessageRow] {
        var result: [HistoryMessageRow] = []
        var offset = 0
        let pageSize = 500
        while offset < total {
            let page = await service.fetchMessagePage(limit: pageSize, offset: offset)
            result.append(contentsOf: page)
            offset += pageSize
        }
        return result
    }

    // MARK: - Aggregation

    /// 在后台线程执行的聚合方法
    nonisolated private static func aggregateByDay(
        _ messages: [HistoryMessageRow],
        days: Int
    ) -> [ActivityDay] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard days > 0 else { return [] }

        // Generate calendar of days (oldest → today).
        guard let oldestDay = cal.date(byAdding: .day, value: -(days - 1), to: today) else {
            return []
        }
        let calendarDays = (0..<days).compactMap {
            cal.date(byAdding: .day, value: $0, to: oldestDay)
        }

        // Count messages per day.
        var counts: [Date: Int] = [:]
        for msg in messages {
            let day = cal.startOfDay(for: msg.timestamp)
            counts[day, default: 0] += 1
        }

        // Normalize max count to 4 levels.
        let maxCount = counts.values.max() ?? 0
        guard maxCount > 0 else {
            return calendarDays.map { ActivityDay(date: $0, level: 0) }
        }

        return calendarDays.map { date in
            let count = counts[date] ?? 0
            let level = min(4, Int(Double(count) / Double(maxCount) * 4.99))
            return ActivityDay(date: date, level: level)
        }
    }
}
