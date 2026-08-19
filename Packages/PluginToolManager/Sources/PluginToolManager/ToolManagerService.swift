import AgentToolKit
import Foundation
import ProviderToolManager

/// PluginToolManager 自研的 `ToolManagerProviding` 实现。
///
/// 组合 `DefaultToolManagerProviding`（与旧版 `ToolManagerService` 同源的
/// 新体系引擎：注册表 / 风险评估 / 执行 / 调用记录），显式实现协议并转发，
/// 同时提供内置文件/终端工具的注册入口与记录存储透传。
@MainActor
public final class ToolManagerService: ToolManagerProviding, ObservableObject {
    /// 内部引擎（注册表 + 执行 + 记录）。
    private let engine: DefaultToolManagerProviding

    /// 工具调用记录存储（与旧版同一数据库目录）。由插件装配阶段注入；
    /// 未设置时记录功能 no-op。
    public var recordStore: ProviderToolManager.ToolCallRecordStore? {
        get { engine.recordStore }
        set { engine.recordStore = newValue }
    }

    public init(engine: DefaultToolManagerProviding = DefaultToolManagerProviding()) {
        self.engine = engine
    }

    /// 注册内置文件/终端工具（归入 "ToolManager" 分组，与旧版 Tools 目录对齐）。
    public func registerBuiltinTools() {
        add(ListDirectoryTool(), pluginID: Self.toolManagerPluginID)
        add(GlobTool(), pluginID: Self.toolManagerPluginID)
        add(ReadFileTool(), pluginID: Self.toolManagerPluginID)
        add(WriteFileTool(), pluginID: Self.toolManagerPluginID)
        add(EditFileTool(), pluginID: Self.toolManagerPluginID)
        add(ReadImageTool(), pluginID: Self.toolManagerPluginID)
        add(ShellTool(), pluginID: Self.toolManagerPluginID)
    }

    /// 内置工具分组 id（设置页分组名）。
    public static let toolManagerPluginID = "com.coffic.lumi.plugin.tool-manager"

    // MARK: - ToolManagerProviding: Registration

    public func allTools() -> [any SuperAgentTool] { engine.allTools() }

    public func add(_ tool: any SuperAgentTool, pluginID: String) {
        engine.add(tool, pluginID: pluginID)
    }

    public func remove(id: String) {
        engine.remove(id: id)
    }

    public func toolsGroupedByPlugin() -> [(pluginID: String, tools: [any SuperAgentTool])] {
        engine.toolsGroupedByPlugin()
    }

    // MARK: - ToolManagerProviding: Execution

    public func tool(named name: String) -> (any SuperAgentTool)? {
        engine.tool(named: name)
    }

    public func displayDescription(for toolCall: ToolCall) -> String? {
        engine.displayDescription(for: toolCall)
    }

    public func riskLevel(for toolCall: ToolCall) -> CommandRiskLevel? {
        engine.riskLevel(for: toolCall)
    }

    public func execute(
        _ toolCall: ToolCall,
        conversationID: UUID,
        turnID: UUID?
    ) async -> ToolCallResult {
        await engine.execute(toolCall, conversationID: conversationID, turnID: turnID)
    }

    public func executeBatch(
        _ toolCalls: [ToolCall],
        policy: ToolExecutionPolicy,
        conversationID: UUID,
        turnID: UUID?
    ) async -> [BatchToolResult] {
        await engine.executeBatch(toolCalls, policy: policy, conversationID: conversationID, turnID: turnID)
    }

    // MARK: - ToolManagerProviding: Records

    public func toolCalls(for turnID: UUID) async -> [ToolCallRecord] {
        await engine.toolCalls(for: turnID)
    }

    public func toolCallResult(for toolCallID: String) async -> ToolCallResult? {
        await engine.toolCallResult(for: toolCallID)
    }

    public func deleteToolCalls(for conversationID: UUID) async {
        await engine.deleteToolCalls(for: conversationID)
    }
}
