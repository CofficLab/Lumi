import Foundation
import KitAgentTool
import ProviderToolManager

/// 工具管理器设置页的唯一数据来源。
///
/// 负责工具分组、工具 / 执行日志 / 调用统计三块内容的选中状态、执行日志分页
/// 与调用统计；所有外部操作经 `ToolManagerCapability` 收敛，View 只读取本 ViewModel。
@MainActor
final class ToolManagerViewModel: ObservableObject {
    /// 设置页的三种视图模式，由头部行的分段控件切换。
    ///
    /// 三种模式共用同一个主从（列表 + 详情）骨架：左侧列表与右侧详情
    /// 随模式一起更换，而不是把三种内容叠在同一个页面里。
    enum Mode: String, Identifiable, CaseIterable {
        case tools
        case executionLog
        case toolStats

        var id: String { rawValue }

        /// 该模式是否依赖调用记录存储。
        ///
        /// 未配置存储时执行日志与调用统计都拿不到数据，需要给出明确的空状态，
        /// 而不是渲染一个永远为空的列表。
        var requiresLogStore: Bool {
            switch self {
            case .tools: return false
            case .executionLog, .toolStats: return true
            }
        }
    }

    /// 左侧列表里的一条工具：工具本体 + 归属插件。
    struct ToolEntry: Identifiable {
        var id: String { tool.name }
        let pluginID: String
        let tool: any SuperAgentTool
    }

    private let capability: any ToolManagerCapability
    private let pageSize = 50
    /// 统计聚合时单页拉取上限。
    private let statsPageSize = 500

    // MARK: - Published State (供 View 展示)

    /// 当前视图模式。
    @Published private(set) var selectedMode: Mode = .tools

    /// 按插件分组的可用工具列表。
    @Published private(set) var groups: [(pluginID: String, tools: [any SuperAgentTool])] = []

    /// 当前选中的工具名。
    @Published private(set) var selectedToolName: String?

    // 执行日志
    @Published private(set) var records: [ToolCallRecord] = []
    @Published private(set) var selectedRecordID: String?
    @Published private(set) var isLoadingLog = false
    @Published private(set) var hasMoreLog = true
    private var logCursorCreatedAt: Date?
    private var logCursorID: String?

    // 调用统计
    @Published private(set) var stats: [ToolStatEntry] = []
    @Published private(set) var selectedStatToolName: String?
    @Published private(set) var totalCallCount = 0

    init(capability: any ToolManagerCapability) {
        self.capability = capability
    }

    // MARK: - 派生状态

    var hasLogStore: Bool {
        capability.hasLogStore
    }

    var totalToolCount: Int {
        groups.reduce(0) { $0 + $1.tools.count }
    }

    /// 扁平化后的工具条目（保持分组顺序），右侧详情按工具名定位。
    var toolEntries: [ToolEntry] {
        groups.flatMap { group in
            group.tools.map { ToolEntry(pluginID: group.pluginID, tool: $0) }
        }
    }

    /// 当前选中的工具条目。
    var selectedTool: ToolEntry? {
        guard let selectedToolName else { return nil }
        return toolEntries.first { $0.tool.name == selectedToolName }
    }

    /// 当前选中的调用记录。
    var selectedRecord: ToolCallRecord? {
        guard let selectedRecordID else { return nil }
        return records.first { $0.id == selectedRecordID }
    }

    /// 当前选中的统计条目。
    var selectedStat: ToolStatEntry? {
        guard let selectedStatToolName else { return nil }
        return stats.first { $0.toolName == selectedStatToolName }
    }

    // MARK: - 用户意图

    /// 切换视图模式，并按新模式加载对应数据。
    func selectMode(_ mode: Mode) {
        selectedMode = mode
        switch mode {
        case .tools:
            Task { await reloadTools() }
        case .executionLog:
            Task { await refreshLog() }
        case .toolStats:
            Task { await reloadStats() }
        }
    }

    /// 头部刷新按钮：按当前模式重新加载。
    func refreshCurrentModeRequested() {
        switch selectedMode {
        case .tools:
            Task { await reloadTools() }
        case .executionLog:
            Task { await refreshLog() }
        case .toolStats:
            Task { await reloadStats() }
        }
    }

    func selectTool(named name: String) {
        selectedToolName = name
    }

    func selectRecord(id: String?) {
        selectedRecordID = id
    }

    func selectStat(named name: String) {
        selectedStatToolName = name
    }

    func refreshLogRequested() {
        Task { await refreshLog() }
    }

    func reloadStatsRequested() {
        Task { await reloadStats() }
    }

    // MARK: - Data

    func reloadTools() async {
        await Task.yield()
        groups = capability.toolsGroupedByPlugin
        // 选中的工具若已下线（插件停用），回落到列表里的第一个。
        if let selectedToolName,
           toolEntries.contains(where: { $0.tool.name == selectedToolName }) {
            return
        }
        selectedToolName = toolEntries.first?.tool.name
    }

    func refreshLog() async {
        guard !isLoadingLog else { return }
        isLoadingLog = true
        logCursorCreatedAt = nil
        logCursorID = nil
        hasMoreLog = true
        let page = await capability.fetchLogPage(
            limit: pageSize,
            beforeCreatedAt: nil,
            beforeID: nil
        )
        records = page
        updateLogCursor(page)
        if selectedRecordID == nil || !records.contains(where: { $0.id == selectedRecordID }) {
            selectedRecordID = records.first?.id
        }
        isLoadingLog = false
    }

    func loadMoreLog() async {
        guard hasMoreLog, !isLoadingLog else { return }
        isLoadingLog = true
        let page = await capability.fetchLogPage(
            limit: pageSize,
            beforeCreatedAt: logCursorCreatedAt,
            beforeID: logCursorID
        )
        records.append(contentsOf: page)
        updateLogCursor(page)
        isLoadingLog = false
    }

    private func updateLogCursor(_ page: [ToolCallRecord]) {
        guard let last = page.last else {
            hasMoreLog = false
            return
        }
        logCursorCreatedAt = last.createdAt
        logCursorID = last.id
        hasMoreLog = page.count >= pageSize
    }

    func reloadStats() async {
        await Task.yield()
        totalCallCount = await capability.countRecords()

        var all: [ToolCallRecord] = []
        var beforeCreatedAt: Date?
        var beforeID: String?
        var hasMore = true
        while hasMore {
            let page = await capability.fetchLogPage(
                limit: statsPageSize,
                beforeCreatedAt: beforeCreatedAt,
                beforeID: beforeID
            )
            all.append(contentsOf: page)
            guard let last = page.last else {
                hasMore = false
                break
            }
            beforeCreatedAt = last.createdAt
            beforeID = last.id
            hasMore = page.count >= statsPageSize
        }

        var map: [String: Accumulator] = [:]
        for record in all {
            var acc = map[record.toolName] ?? Accumulator()
            acc.totalCount += 1
            if record.resultIsError { acc.errorCount += 1 }
            if let duration = record.duration { acc.totalDuration += duration }
            map[record.toolName] = acc
        }
        stats = map.map { name, acc in
            ToolStatEntry(
                toolName: name,
                errorCount: acc.errorCount,
                totalCount: acc.totalCount,
                averageDuration: acc.totalCount > 0 ? acc.totalDuration / Double(acc.totalCount) : 0
            )
        }
        .sorted { $0.totalCount > $1.totalCount }

        // 选中的统计项若已不存在，回落到调用次数最多的那一项。
        if let selectedStatToolName,
           stats.contains(where: { $0.toolName == selectedStatToolName }) {
            return
        }
        selectedStatToolName = stats.first?.toolName
    }
}

/// 单工具统计。
struct ToolStatEntry: Identifiable {
    var id: String { toolName }
    let toolName: String
    let errorCount: Int
    let totalCount: Int
    let averageDuration: Double

    /// 错误率（百分比）。
    var errorRate: Double {
        guard totalCount > 0 else { return 0 }
        return Double(errorCount) / Double(totalCount) * 100
    }
}

private struct Accumulator {
    var totalCount = 0
    var errorCount = 0
    var totalDuration: TimeInterval = 0
}
