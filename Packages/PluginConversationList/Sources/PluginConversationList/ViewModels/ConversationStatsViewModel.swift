import Combine
import Foundation
import ProviderConversation

/// 对话条数徽标弹出的「对话统计」面板的唯一数据来源与交互入口。
///
/// 面板内容：
/// - 每日对话数量折线图（最近 `chartDays` 天，按创建日聚合）；
/// - 「清理 7 天前的对话」「清理 30 天前的对话」两个批量清理入口。
///
/// 统计口径与列表一致：顶层对话，不含子 Agent 会话。
@MainActor
final class ConversationStatsViewModel: ObservableObject {
    /// 可选的时间窗口（天）。
    enum RetentionWindow: Int, CaseIterable, Identifiable {
        case sevenDays = 7
        case thirtyDays = 30

        var id: Int { rawValue }

        /// 清理按钮上展示的天数文案。
        var dayCount: Int { rawValue }
    }

    /// 折线图覆盖的天数。
    static let chartDays = 30

    /// 每日对话计数序列。
    @Published private(set) var dailyCountSeries = ConversationDailyCountSeries(points: [])

    /// 各清理窗口对应的待删除条数（键为窗口原始值）。
    ///
    /// 破坏性操作前告诉用户「会删掉多少」，比只显示天数有用。
    @Published private(set) var deletableCounts: [Int: Int] = [:]

    /// 是否正在加载统计。
    @Published private(set) var isLoading = false

    /// 是否正在执行批量清理。
    @Published private(set) var isCleaning = false

    /// 当前作用域的项目路径；`nil` 表示全库。
    let projectPath: String?

    private let capability: any ConversationStatsCapability
    private var isLoadingSeries = false

    init(capability: any ConversationStatsCapability, projectPath: String?) {
        self.capability = capability
        self.projectPath = projectPath
    }

    // MARK: - Derived

    /// 折线图覆盖区间内的对话总数。
    var totalInRange: Int {
        dailyCountSeries.totalCount
    }

    /// 单日峰值。
    var peakCount: Int {
        dailyCountSeries.peakCount
    }

    /// 某天之前有多少条对话可被清理。
    ///
    /// 直接向存储层查询，而不是从折线图推断——折线图只覆盖最近 30 天，
    /// 图外的历史对话数必须查库才准确。
    func deletableCount(for window: RetentionWindow) async -> Int {
        await capability.conversationCount(
            createdBefore: Self.cutoff(for: window),
            projectPath: projectPath,
            includingChildConversations: false
        )
    }

    // MARK: - 数据加载

    /// 加载每日计数序列与各窗口的待删除条数。重复调用不会并发触发。
    func loadSeriesIfNeeded() async {
        guard !isLoadingSeries else { return }
        isLoadingSeries = true
        isLoading = true
        defer {
            isLoadingSeries = false
            isLoading = false
        }

        let series = await capability.fetchDailyCountSeries(
            days: Self.chartDays,
            projectPath: projectPath,
            includingChildConversations: false
        )
        dailyCountSeries = series
        await loadDeletableCounts()
    }

    /// 查询各清理窗口的待删除条数。
    private func loadDeletableCounts() async {
        var counts: [Int: Int] = [:]
        for window in RetentionWindow.allCases {
            counts[window.dayCount] = await deletableCount(for: window)
        }
        deletableCounts = counts
    }

    /// 清理「N 天前」的对话，返回被删除的条数。
    @discardableResult
    func cleanUp(olderThan window: RetentionWindow) async -> Int {
        guard !isCleaning else { return 0 }
        isCleaning = true
        defer { isCleaning = false }

        let deleted = await capability.deleteConversations(
            createdBefore: Self.cutoff(for: window),
            projectPath: projectPath,
            includingChildConversations: false
        )
        // 清理后立即刷新折线图与待删除条数，让用户看到结果。
        let series = await capability.fetchDailyCountSeries(
            days: Self.chartDays,
            projectPath: projectPath,
            includingChildConversations: false
        )
        dailyCountSeries = series
        await loadDeletableCounts()
        return deleted.count
    }

    // MARK: - Private

    /// 「N 天前」的时间分界点：从今天零点往前推 N 天。
    ///
    /// 用「今天零点 - N 天」而不是「现在 - N×24 小时」，是为了让
    /// 「7 天前」在语义上等于「7 个自然日之前」，与折线图的自然日分桶一致。
    private static func cutoff(for window: RetentionWindow) -> Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return calendar.date(
            byAdding: .day,
            value: -window.dayCount,
            to: today
        ) ?? today
    }
}
