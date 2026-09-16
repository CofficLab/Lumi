import Foundation
import ProviderMessage
import Testing
@testable import PluginActivityHeatmap

@Suite("Activity heatmap view model")
@MainActor
struct ActivityHeatmapViewModelTests {
    @Test("loads missing history once, combines cached days with today's live counts")
    func reloadsAndCachesDailyCounts() async {
        let defaults = UserDefaults.standard
        let previousPeriod = defaults.object(forKey: ActivityHeatmapViewModel.periodKey)
        defer {
            if let previousPeriod {
                defaults.set(previousPeriod, forKey: ActivityHeatmapViewModel.periodKey)
            } else {
                defaults.removeObject(forKey: ActivityHeatmapViewModel.periodKey)
            }
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let firstDay = calendar.date(byAdding: .day, value: -29, to: today)!
        let heatmapFirstDay = calendar.date(byAdding: .day, value: -364, to: today)!
        let activeDay = calendar.date(byAdding: .day, value: -2, to: today)!
        let previousActiveDay = calendar.date(byAdding: .day, value: -1, to: today)!
        let manager = HeatmapMessageManager(
            messageCounts: [activeDay: 4, previousActiveDay: 2, today: 7],
            tokenCounts: [activeDay: 400, previousActiveDay: 200, today: 700]
        )
        let cache = ActivityHeatmapCache(directory: nil)
        let viewModel = ActivityHeatmapViewModel(messages: manager, cache: cache)
        viewModel.period = .days30

        await viewModel.reload()

        #expect(viewModel.isLoading == false)
        #expect(viewModel.days.count == 30)
        #expect(viewModel.days.first?.date == firstDay)
        #expect(viewModel.days.last?.date == today)
        #expect(viewModel.heatmapDays.count == 365)
        #expect(viewModel.heatmapDays.first?.date == heatmapFirstDay)
        #expect(viewModel.heatmapDays.last?.date == today)
        #expect(viewModel.days.first(where: { calendar.isDate($0.date, inSameDayAs: activeDay) })?.messages == 4)
        #expect(viewModel.days.first(where: { calendar.isDate($0.date, inSameDayAs: activeDay) })?.tokens == 400)
        #expect(viewModel.days.first(where: { calendar.isDate($0.date, inSameDayAs: previousActiveDay) })?.messages == 2)
        #expect(viewModel.days.first(where: { calendar.isDate($0.date, inSameDayAs: today) })?.messages == 7)
        #expect(viewModel.days.first(where: { calendar.isDate($0.date, inSameDayAs: today) })?.tokens == 700)
        #expect(manager.messageQueryDates == [heatmapFirstDay, today])
        #expect(manager.tokenQueryDates == [heatmapFirstDay, today])

        await viewModel.reload()

        #expect(manager.messageQueryDates == [heatmapFirstDay, today, today])
        #expect(manager.tokenQueryDates == [heatmapFirstDay, today, today])
        #expect(viewModel.days.count == 30)
        #expect(viewModel.heatmapDays.count == 365)
    }

    @Test("peak token day picks the busiest day inside the trend window")
    func reportsPeakTokenDay() async {
        let defaults = UserDefaults.standard
        let previousPeriod = defaults.object(forKey: ActivityHeatmapViewModel.periodKey)
        defer {
            if let previousPeriod {
                defaults.set(previousPeriod, forKey: ActivityHeatmapViewModel.periodKey)
            } else {
                defaults.removeObject(forKey: ActivityHeatmapViewModel.periodKey)
            }
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let busiestDay = calendar.date(byAdding: .day, value: -3, to: today)!
        let busyDay = calendar.date(byAdding: .day, value: -5, to: today)!

        let manager = HeatmapMessageManager(
            messageCounts: [busiestDay: 3, busyDay: 2, today: 1],
            tokenCounts: [busiestDay: 5_000, busyDay: 900, today: 100]
        )
        let viewModel = ActivityHeatmapViewModel(messages: manager, cache: ActivityHeatmapCache(directory: nil))
        viewModel.period = .days30

        await viewModel.reload()

        #expect(viewModel.trendDays.count == ActivityHeatmapPeriod.days30.rawValue)
        #expect(viewModel.trendDays.last?.date == today)
        #expect(viewModel.peakTokenDay?.date == busiestDay)
        #expect(viewModel.peakTokenDay?.tokens == 5_000)

        let idleViewModel = ActivityHeatmapViewModel(
            messages: HeatmapMessageManager(messageCounts: [:], tokenCounts: [:]),
            cache: ActivityHeatmapCache(directory: nil)
        )

        await idleViewModel.reload()

        #expect(idleViewModel.peakTokenDay == nil)
    }

    @Test("peak token day ignores consumption outside the trend window")
    func ignoresConsumptionOutsideTrendWindow() async {
        let defaults = UserDefaults.standard
        let previousPeriod = defaults.object(forKey: ActivityHeatmapViewModel.periodKey)
        defer {
            if let previousPeriod {
                defaults.set(previousPeriod, forKey: ActivityHeatmapViewModel.periodKey)
            } else {
                defaults.removeObject(forKey: ActivityHeatmapViewModel.periodKey)
            }
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let staleHeavyDay = calendar.date(byAdding: .day, value: -100, to: today)!
        let recentDay = calendar.date(byAdding: .day, value: -2, to: today)!

        let manager = HeatmapMessageManager(
            messageCounts: [staleHeavyDay: 20, recentDay: 1],
            tokenCounts: [staleHeavyDay: 900_000, recentDay: 120]
        )
        let viewModel = ActivityHeatmapViewModel(messages: manager, cache: ActivityHeatmapCache(directory: nil))
        viewModel.period = .days30

        await viewModel.reload()

        #expect(viewModel.heatmapDays.contains { calendar.isDate($0.date, inSameDayAs: staleHeavyDay) })
        #expect(viewModel.trendDays.contains { calendar.isDate($0.date, inSameDayAs: staleHeavyDay) } == false)
        #expect(viewModel.peakTokenDay?.date == recentDay)
    }
}

@MainActor
private final class HeatmapMessageManager: MessageManaging {
    private let messageCounts: [Date: Int]
    private let tokenCounts: [Date: Int]
    private(set) var messageQueryDates: [Date] = []
    private(set) var tokenQueryDates: [Date] = []

    init(messageCounts: [Date: Int], tokenCounts: [Date: Int]) {
        self.messageCounts = messageCounts
        self.tokenCounts = tokenCounts
    }

    func messages(for conversationID: UUID) -> [Message] { [] }
    func message(id: UUID, in conversationID: UUID) -> Message? { nil }
    func lastMessage(in conversationID: UUID) -> Message? { nil }
    func messageCount(for conversationID: UUID) -> Int { 0 }

    func dailyMessageCountsAsync(since: Date) async -> [Date: Int] {
        messageQueryDates.append(since)
        return messageCounts.filter { $0.key >= since }
    }

    func dailyTokenCountsAsync(since: Date) async -> [Date: Int] {
        tokenQueryDates.append(since)
        return tokenCounts.filter { $0.key >= since }
    }

    func insertMessage(_ message: Message, to conversationID: UUID) {}
    func updateMessage(id: UUID, in conversationID: UUID, content: String) {}
    func deleteMessage(id: UUID, in conversationID: UUID) {}
    func clearMessages(in conversationID: UUID) {}

    func updateToolCallResult(
        _ result: MessageToolResult,
        toolCallID: String,
        assistantMessageID: UUID,
        in conversationID: UUID,
        authorizationState: String?
    ) {}
}
