import AppKit
import Foundation
import KitAgentTool
import ProviderToolManager

/// 工具管理器设置页的唯一数据来源。
///
/// 负责工具分组、执行日志分页、调用统计与选中 Tab 等业务状态；
/// 所有外部操作经 `ToolManagerCapability` 收敛，View 只读取本 ViewModel。
@MainActor
final class ToolManagerViewModel: ObservableObject {
    /// 顶部 Tab。
    enum Tab: String, Identifiable {
        case tools
        case executionLog
        case toolStats

        var id: String { rawValue }
    }

    private let capability: any ToolManagerCapability
    private let pageSize = 50
    /// 统计聚合时单页拉取上限。
    private let statsPageSize = 500

    // MARK: - Published State (供 View 展示)

    @Published private(set) var selectedTabID: Tab = .tools

    /// 按插件分组的可用工具列表。
    @Published private(set) var groups: [(pluginID: String, tools: [any SuperAgentTool])] = []

    // 执行日志
    @Published private(set) var records: [ToolCallRecord] = []
    @Published private(set) var selectedRecordID: String?
    @Published private(set) var isLoadingLog = false
    @Published private(set) var hasMoreLog = true
    private var logCursorCreatedAt: Date?
    private var logCursorID: String?

    // 调用统计
    @Published private(set) var stats: [ToolStatEntry] = []
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

    var selectedRecord: ToolCallRecord? {
        guard let selectedRecordID else { return nil }
        return records.first { $0.id == selectedRecordID }
    }

    var tabTitle: [Tab: String] {
        [
            .tools: L("Tools"),
            .executionLog: L("Execution Log"),
            .toolStats: L("Usage Statistics"),
        ]
    }

    // MARK: - 用户意图

    func selectTab(_ tab: Tab) {
        selectedTabID = tab
        switch tab {
        case .tools:
            Task { await reloadTools() }
        case .executionLog:
            Task { await refreshLog() }
        case .toolStats:
            Task { await reloadStats() }
        }
    }

    func selectRecord(id: String?) {
        selectedRecordID = id
    }

    func refreshLogRequested() {
        Task { await refreshLog() }
    }

    func reloadStatsRequested() {
        Task { await reloadStats() }
    }

    func openDataDirectory() {
        let url = capability.storeDirectory
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
                .appendingPathComponent("com.coffic.Lumi", isDirectory: true)
        guard let url else { return }
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        NSWorkspace.shared.open(url)
    }

    // MARK: - Data

    func reloadTools() async {
        await Task.yield()
        groups = capability.toolsGroupedByPlugin
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
    }

    private func L(_ key: String) -> String {
        LumiPluginLocalization.string(key, bundle: .module)
    }
}

/// 单工具统计。
struct ToolStatEntry: Identifiable {
    var id: String { toolName }
    let toolName: String
    let errorCount: Int
    let totalCount: Int
    let averageDuration: Double
}

private struct Accumulator {
    var totalCount = 0
    var errorCount = 0
    var totalDuration: TimeInterval = 0
}
