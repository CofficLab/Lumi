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

    func countRecords() async -> Int { records.count }

    func fetchLogPage(
        limit: Int,
        beforeCreatedAt: Date?,
        beforeID: String?
    ) async -> [ToolCallRecord] {
        Array(records.prefix(limit))
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
    isError: Bool = false
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
        duration: nil,
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
