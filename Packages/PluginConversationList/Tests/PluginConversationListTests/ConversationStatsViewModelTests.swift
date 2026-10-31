import Foundation
import ProviderConversation
import Testing
@testable import PluginConversationList

/// 「对话统计」面板（每日计数 + 按时间批量清理）的单元测试。
@MainActor
@Suite("ConversationStats")
struct ConversationStatsViewModelTests {
    @Test("加载每日计数序列并暴露区间总数与峰值")
    func loadsDailySeries() async {
        let capability = StubStatsCapability()
        capability.series = ConversationDailyCountSeries(points: [
            ConversationDailyCountPoint(day: Date(timeIntervalSince1970: 0), count: 1),
            ConversationDailyCountPoint(day: Date(timeIntervalSince1970: 86_400), count: 4),
            ConversationDailyCountPoint(day: Date(timeIntervalSince1970: 172_800), count: 2),
        ])
        let viewModel = ConversationStatsViewModel(capability: capability, projectPath: nil)

        await viewModel.loadSeriesIfNeeded()

        #expect(viewModel.dailyCountSeries.points.count == 3)
        #expect(viewModel.totalInRange == 7)
        #expect(viewModel.peakCount == 4)
        #expect(capability.requestedDays == ConversationStatsViewModel.chartDays)
        #expect(capability.requestedProjectPath == nil)
        #expect(capability.requestedIncludingChildConversations == false)
    }

    @Test("统计作用域跟随当前项目")
    func scopesToCurrentProject() async {
        let capability = StubStatsCapability()
        let viewModel = ConversationStatsViewModel(capability: capability, projectPath: "/workspace/One")

        await viewModel.loadSeriesIfNeeded()

        #expect(capability.requestedProjectPath == "/workspace/One")
        #expect(viewModel.projectPath == "/workspace/One")
    }

    @Test("清理按创建时间分界点执行并刷新序列")
    func cleansUpOlderConversations() async {
        let capability = StubStatsCapability()
        capability.deletedIDs = [UUID(), UUID(), UUID()]
        let viewModel = ConversationStatsViewModel(capability: capability, projectPath: nil)

        let deleted = await viewModel.cleanUp(olderThan: .sevenDays)

        #expect(deleted == 3)
        #expect(capability.deletedCount == 1)
        // 清理分界点应是「今天零点 - 7 天」。
        let expectedCutoff = Calendar.current.date(
            byAdding: .day,
            value: -7,
            to: Calendar.current.startOfDay(for: Date())
        )
        #expect(capability.lastDeleteCutoff == expectedCutoff)
        #expect(capability.requestedProjectPath == nil)
        #expect(capability.requestedIncludingChildConversations == false)
    }

    @Test("30 天窗口的分界点早于 7 天窗口")
    func thirtyDayWindowCutsOffEarlier() async {
        let capability = StubStatsCapability()
        let viewModel = ConversationStatsViewModel(capability: capability, projectPath: nil)

        await viewModel.cleanUp(olderThan: .sevenDays)
        let sevenDayCutoff = capability.lastDeleteCutoff

        await viewModel.cleanUp(olderThan: .thirtyDays)
        let thirtyDayCutoff = capability.lastDeleteCutoff

        #expect(thirtyDayCutoff != nil)
        #expect(sevenDayCutoff != nil)
        #expect(thirtyDayCutoff! < sevenDayCutoff!)
    }

    @Test("可清理数量由存储层查询给出")
    func reportsDeletableCount() async {
        let capability = StubStatsCapability()
        capability.deletableCount = 12
        let viewModel = ConversationStatsViewModel(capability: capability, projectPath: nil)

        let count = await viewModel.deletableCount(for: .sevenDays)

        #expect(count == 12)
    }

    @Test("加载时一并取回各窗口的待删除条数")
    func loadsDeletableCountsForAllWindows() async {
        let capability = StubStatsCapability()
        capability.deletableCount = 5
        let viewModel = ConversationStatsViewModel(capability: capability, projectPath: nil)

        await viewModel.loadSeriesIfNeeded()

        #expect(viewModel.deletableCounts[7] == 5)
        #expect(viewModel.deletableCounts[30] == 5)
        #expect(capability.lastCountCutoff != nil)
    }

    @Test("清理后刷新待删除条数")
    func refreshesDeletableCountsAfterCleanup() async {
        let capability = StubStatsCapability()
        capability.deletableCount = 9
        let viewModel = ConversationStatsViewModel(capability: capability, projectPath: nil)

        await viewModel.loadSeriesIfNeeded()
        let before = viewModel.deletableCounts[7]

        capability.deletableCount = 0
        _ = await viewModel.cleanUp(olderThan: .sevenDays)

        #expect(before == 9)
        #expect(viewModel.deletableCounts[7] == 0)
    }

    @Test("清理期间重复触发只执行一次")
    func ignoresConcurrentCleanup() async {
        let capability = StubStatsCapability()
        let viewModel = ConversationStatsViewModel(capability: capability, projectPath: nil)

        async let first = viewModel.cleanUp(olderThan: .sevenDays)
        async let second = viewModel.cleanUp(olderThan: .thirtyDays)
        _ = await (first, second)

        #expect(capability.deletedCount == 1)
    }
}

/// `ConversationStatsCapability` 的测试替身。
@MainActor
private final class StubStatsCapability: ConversationStatsCapability {
    var series = ConversationDailyCountSeries(points: [])
    var deletedIDs: [UUID] = []
    var deletableCount = 0

    private(set) var requestedDays: Int?
    private(set) var requestedProjectPath: String?
    private(set) var requestedIncludingChildConversations = true
    private(set) var deletedCount = 0
    /// 删除操作使用的分界点。
    private(set) var lastDeleteCutoff: Date?
    /// 计数查询使用的分界点。
    private(set) var lastCountCutoff: Date?

    func fetchDailyCountSeries(
        days: Int,
        projectPath: String?,
        includingChildConversations: Bool
    ) async -> ConversationDailyCountSeries {
        requestedDays = days
        requestedProjectPath = projectPath
        requestedIncludingChildConversations = includingChildConversations
        return series
    }

    func deleteConversations(
        createdBefore cutoff: Date,
        projectPath: String?,
        includingChildConversations: Bool
    ) async -> [UUID] {
        deletedCount += 1
        lastDeleteCutoff = cutoff
        requestedProjectPath = projectPath
        requestedIncludingChildConversations = includingChildConversations
        // 真实存储层操作会挂起，这里同样让出执行权，
        // 才能真实模拟「两个清理请求同时到达」的重叠场景。
        await Task.yield()
        return deletedIDs
    }

    func conversationCount(
        createdBefore cutoff: Date,
        projectPath: String?,
        includingChildConversations: Bool
    ) async -> Int {
        lastCountCutoff = cutoff
        return deletableCount
    }
}
