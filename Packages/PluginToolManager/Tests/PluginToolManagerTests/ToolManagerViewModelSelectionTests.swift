import Foundation
import KitAgentTool
import ProviderToolManager
import Testing
@testable import PluginToolManager

/// 工具设置页「左侧列表 + 右侧详情」结构的 ViewModel 不变式。
///
/// 主从布局要求「列表里有东西时详情栏必须有选中项」，否则右侧会一直停在
/// 空状态，用户在左栏点了也看不到反应。这些用例把这条不变式钉在 ViewModel
/// 上，与具体视图实现解耦。
/// 用引用类型（class）而不是结构体：ViewModel 持有的是 `any ToolManagerCapability`
/// 存在值，结构体会在传入时被拷贝一份，测试后续改不动 ViewModel 看到的数据。
@MainActor
private final class StubCapability: ToolManagerCapability {
    var toolsGroupedByPlugin: [(pluginID: String, tools: [any SuperAgentTool])] = []
    var hasLogStore = true
    var records: [ToolCallRecord] = []
    var pageDelay: Duration?
    /// 只延迟「带游标的翻页请求」，用于构造翻页中途刷新的场景。
    var delaysPaginationOnly = false
    /// 对每一页（含首页）都施加延迟，用于构造统计加载中的重叠触发。
    var allPagesDelay: Duration?
    /// fetchLogPage 被调用的累计次数，用于断言重入守卫挡住重复拉取。
    var fetchPageCount = 0

    func countRecords() async -> Int { records.count }

    func fetchLogPage(
        limit: Int,
        beforeCreatedAt: Date?,
        beforeID: String?
    ) async -> [ToolCallRecord] {
        fetchPageCount += 1
        if let allPagesDelay {
            try? await Task.sleep(for: allPagesDelay)
        }
        if delaysPaginationOnly, beforeID != nil, let pageDelay {
            try? await Task.sleep(for: pageDelay)
        }
        var start = 0
        if let beforeID,
           let index = records.firstIndex(where: { $0.id == beforeID }) {
            start = index + 1
        }
        return Array(records.dropFirst(start).prefix(limit))
    }
}

private struct StubTool: SuperAgentTool, @unchecked Sendable {
    let name: String

    func description(for language: LanguagePreference) -> String { name }
    func inputSchema(for language: LanguagePreference) -> [String: Any] { [:] }
    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .low }
    func displayDescription(for arguments: [String: ToolArgument]) -> String { name }
    func execute(arguments: [String: ToolArgument]) async throws -> String { name }
}

private func makeRecord(
    id: String,
    toolName: String,
    isError: Bool = false,
    duration: TimeInterval? = nil
) -> ToolCallRecord {
    ToolCallRecord(
        id: id,
        toolCallID: nil,
        toolName: toolName,
        toolDisplayName: toolName,
        turnID: nil,
        conversationID: UUID(),
        createdAt: Date(),
        startedAt: Date(),
        completedAt: nil,
        duration: duration,
        argumentsJSON: "{}",
        resultContent: isError ? "boom" : "ok",
        resultJSON: nil,
        resultIsError: isError,
        riskLevel: "low"
    )
}

@MainActor
@Test("工具列表加载后自动选中第一个工具，详情栏不会停在空状态")
func toolListAutoSelectsFirstTool() async {
    var capability = StubCapability()
    capability.toolsGroupedByPlugin = [
        ("plugin-a", [StubTool(name: "read_file")]),
        ("plugin-b", [StubTool(name: "write_file"), StubTool(name: "edit_file")]),
    ]
    let viewModel = ToolManagerViewModel(capability: capability)

    await viewModel.reloadTools()

    #expect(viewModel.selectedToolName == "read_file")
    #expect(viewModel.selectedTool?.pluginID == "plugin-a")
    #expect(viewModel.selectedTool?.tool.name == "read_file")
}

@MainActor
@Test("工具列表按分组顺序扁平化，条目标识即工具名")
func toolEntriesFlattenGroupsInOrder() async {
    var capability = StubCapability()
    capability.toolsGroupedByPlugin = [
        ("plugin-a", [StubTool(name: "read_file")]),
        ("plugin-b", [StubTool(name: "write_file"), StubTool(name: "edit_file")]),
    ]
    let viewModel = ToolManagerViewModel(capability: capability)

    await viewModel.reloadTools()

    #expect(viewModel.toolEntries.map(\.tool.name) == ["read_file", "write_file", "edit_file"])
    #expect(viewModel.toolEntries.map(\.pluginID) == ["plugin-a", "plugin-b", "plugin-b"])
    #expect(viewModel.totalToolCount == 3)
}

@MainActor
@Test("选中的工具在列表刷新后仍然保持选中")
func selectedToolSurvivesReload() async {
    var capability = StubCapability()
    capability.toolsGroupedByPlugin = [
        ("plugin-a", [StubTool(name: "read_file"), StubTool(name: "write_file")]),
    ]
    let viewModel = ToolManagerViewModel(capability: capability)
    await viewModel.reloadTools()

    viewModel.selectTool(named: "write_file")
    await viewModel.reloadTools()

    #expect(viewModel.selectedToolName == "write_file")
    #expect(viewModel.selectedTool?.tool.name == "write_file")
}

@MainActor
@Test("选中的工具被移除后回落到列表里的第一个")
func selectedToolFallsBackWhenToolDisappears() async {
    var capability = StubCapability()
    capability.toolsGroupedByPlugin = [
        ("plugin-a", [StubTool(name: "read_file"), StubTool(name: "write_file")]),
    ]
    let viewModel = ToolManagerViewModel(capability: capability)
    await viewModel.reloadTools()
    viewModel.selectTool(named: "write_file")

    capability.toolsGroupedByPlugin = [
        ("plugin-a", [StubTool(name: "read_file")]),
    ]
    await viewModel.reloadTools()

    #expect(viewModel.selectedToolName == "read_file")
}

@MainActor
@Test("调用统计加载后自动选中第一条，详情栏不会停在空状态")
func statsAutoSelectFirstEntry() async {
    var capability = StubCapability()
    // 让 read_file 的调用次数明确多于 write_file，避免同分时排序不稳定。
    capability.records = [
        makeRecord(id: "r1", toolName: "read_file"),
        makeRecord(id: "r2", toolName: "write_file", isError: true),
        makeRecord(id: "r3", toolName: "read_file"),
    ]
    let viewModel = ToolManagerViewModel(capability: capability)

    await viewModel.reloadStats()

    #expect(viewModel.totalCallCount == 3)
    #expect(viewModel.stats.map(\.toolName) == ["read_file", "write_file"])
    #expect(viewModel.selectedStatToolName == "read_file")
    #expect(viewModel.selectedStat?.toolName == "read_file")
}

@MainActor
@Test("统计详情给出错误率")
func statEntryExposesErrorRate() {
    let entry = ToolStatEntry(
        toolName: "write_file",
        errorCount: 1,
        totalCount: 4,
        averageDuration: 0.5
    )

    #expect(abs(entry.errorRate - 25) < 0.0001)
}

@MainActor
@Test("执行日志加载后自动选中第一条记录")
func logAutoSelectsFirstRecord() async {
    var capability = StubCapability()
    capability.records = [
        makeRecord(id: "r1", toolName: "read_file"),
        makeRecord(id: "r2", toolName: "write_file"),
    ]
    let viewModel = ToolManagerViewModel(capability: capability)

    await viewModel.refreshLog()

    #expect(viewModel.selectedRecordID == "r1")
    #expect(viewModel.selectedRecord?.toolName == "read_file")
}

@MainActor
@Test("三种模式里只有工具模式不依赖调用记录存储")
func onlyToolModeWorksWithoutLogStore() {
    var capability = StubCapability()
    capability.hasLogStore = false
    let viewModel = ToolManagerViewModel(capability: capability)

    #expect(ToolManagerViewModel.Mode.allCases.count == 3)
    #expect(ToolManagerViewModel.Mode.tools.requiresLogStore == false)
    #expect(ToolManagerViewModel.Mode.executionLog.requiresLogStore == true)
    #expect(ToolManagerViewModel.Mode.toolStats.requiresLogStore == true)
    #expect(viewModel.hasLogStore == false)
}

@MainActor
@Test("翻页期间刷新不会被挡住，迟到的翻页结果也不会追加")
func refreshDuringPaginationDropsStalePage() async {
    var capability = StubCapability()
    capability.records = (0..<120).map { makeRecord(id: "r\($0)", toolName: "read_file") }
    capability.pageDelay = .milliseconds(300)
    capability.delaysPaginationOnly = true
    let viewModel = ToolManagerViewModel(capability: capability)

    await viewModel.refreshLog()
    #expect(viewModel.records.count == 50)

    let loadMore = Task { await viewModel.loadMoreLog() }
    while !viewModel.isLoadingMoreLog {
        await Task.yield()
    }

    // 翻页未结束时刷新必须真的执行，而不是被共用标记静默挡回。
    await viewModel.refreshLog()
    #expect(viewModel.records.count == 50)
    #expect(!viewModel.isLoadingLog)

    await loadMore.value
    // 旧列表的第二页不能追加到刚刷新出来的列表尾部。
    #expect(viewModel.records.count == 50)
    #expect(!viewModel.isLoadingMoreLog)
}

@MainActor
@Test("切换模式会切换当前模式并加载对应数据")
func selectModeSwitchesMode() async {
    var capability = StubCapability()
    capability.records = [makeRecord(id: "r1", toolName: "read_file")]
    let viewModel = ToolManagerViewModel(capability: capability)

    viewModel.selectMode(.executionLog)
    #expect(viewModel.selectedMode == .executionLog)

    // 模式切换触发的加载是异步的，等它落定再断言数据已就位。
    _ = try? await Task.sleep(nanoseconds: 200_000_000)
    #expect(viewModel.records.count == 1)
    #expect(viewModel.selectedRecordID == "r1")
}

@MainActor
@Test("统计跨多页聚合结果正确，不驻留整段历史（#1302）")
func statsAggregateAcrossPages() async {
    let capability = StubCapability()
    // 1200 条 > 单页 500，强制翻 3 页；read_file 700 次（含 100 错误、每条 0.5s），
    // write_file 500 次（含 50 错误）。逐页归约后合并必须与一次性聚合一致。
    var records: [ToolCallRecord] = []
    for index in 0..<700 {
        records.append(
            makeRecord(
                id: "read-\(index)",
                toolName: "read_file",
                isError: index < 100,
                duration: 0.5
            )
        )
    }
    for index in 0..<500 {
        records.append(
            makeRecord(id: "write-\(index)", toolName: "write_file", isError: index < 50)
        )
    }
    capability.records = records
    let viewModel = ToolManagerViewModel(capability: capability)

    await viewModel.reloadStats()

    #expect(viewModel.totalCallCount == 1200)
    #expect(viewModel.stats.map(\.toolName) == ["read_file", "write_file"])
    let read = viewModel.stats.first { $0.toolName == "read_file" }
    #expect(read?.totalCount == 700)
    #expect(read?.errorCount == 100)
    #expect(abs((read?.averageDuration ?? 0) - 0.5) < 0.0001)
    let write = viewModel.stats.first { $0.toolName == "write_file" }
    #expect(write?.totalCount == 500)
    #expect(write?.errorCount == 50)
    // 确实翻了多页（3 页：500 + 500 + 200）。
    #expect(capability.fetchPageCount == 3)
}

@MainActor
@Test("统计加载中的重叠触发被重入守卫挡住，不重复拉取（#1302）")
func statsReentryGuardDropsOverlappingReload() async {
    let capability = StubCapability()
    capability.records = (0..<600).map { makeRecord(id: "r\($0)", toolName: "read_file") }
    capability.allPagesDelay = .milliseconds(150)
    let viewModel = ToolManagerViewModel(capability: capability)

    let first = Task { await viewModel.reloadStats() }
    while !viewModel.isLoadingStats {
        await Task.yield()
    }

    // 加载仍在进行时再次触发：守卫必须立即返回，而不是又拉一遍整段历史。
    await viewModel.reloadStats()
    await first.value

    // 单次运行只需 2 页（500 + 100）；没有守卫时重叠触发会翻倍。
    #expect(capability.fetchPageCount == 2)
    #expect(viewModel.totalCallCount == 600)
    #expect(viewModel.stats.first?.totalCount == 600)
    #expect(!viewModel.isLoadingStats)
}
