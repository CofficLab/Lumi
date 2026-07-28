import Foundation
import LumiKernel

/// Agent 工具服务实现
@MainActor
public final class ToolManagerService: ToolManaging {

    /// Kernel 引用，用于在执行工具时直接传递给工具
    public weak var kernel: LumiKernel?

    /// 已注册的工具
    private var registeredTools: [String: any LumiAgentTool] = [:]

    /// 工具注册顺序
    private var toolOrder: [String] = []

    /// 工具归属插件的反向索引：pluginID -> [tool.name]
    /// 用于状态栏「可用工具」按插件分组展示。
    private var pluginToolIndex: [String: [String]] = [:]

    /// 插件首次出现顺序，决定分组在 UI 中的排列。
    private var pluginOrder: [String] = []

    public init() {}

    // MARK: - ToolManaging

    public func allAgentTools() -> [any LumiAgentTool] {
        toolOrder.compactMap { registeredTools[$0] }
    }

    public func add(_ tool: any LumiAgentTool, pluginID: String) {
        if registeredTools[tool.name] == nil {
            toolOrder.append(tool.name)
        }
        registeredTools[tool.name] = tool

        // 迁移归属：若该工具此前属于其它插件分组，先从原分组移除。
        for (existingPlugin, names) in pluginToolIndex where names.contains(tool.name) {
            pluginToolIndex[existingPlugin]?.removeAll { $0 == tool.name }
        }

        if pluginToolIndex[pluginID] == nil, !pluginOrder.contains(pluginID) {
            pluginOrder.append(pluginID)
        }
        pluginToolIndex[pluginID, default: []].append(tool.name)
    }

    public func remove(id: String) {
        registeredTools.removeValue(forKey: id)
        toolOrder.removeAll { $0 == id }

        for (pluginID, names) in pluginToolIndex where names.contains(id) {
            pluginToolIndex[pluginID]?.removeAll { $0 == id }
            if pluginToolIndex[pluginID]?.isEmpty == true {
                pluginToolIndex.removeValue(forKey: pluginID)
                pluginOrder.removeAll { $0 == pluginID }
            }
        }
    }

    public func agentToolsGroupedByPlugin() -> [(pluginID: String, tools: [any LumiAgentTool])] {
        pluginOrder.compactMap { pluginID in
            let names = pluginToolIndex[pluginID] ?? []
            let tools = names.compactMap { registeredTools[$0] }
            return tools.isEmpty ? nil : (pluginID, tools)
        }
    }

    public func allSubAgents() -> [LumiSubAgentDefinition] {
        []
    }

    public func addSubAgent(_ subAgent: LumiSubAgentDefinition) {}

    public func collectTools() async throws -> [any LumiAgentTool] {
        allAgentTools()
    }

    // MARK: - Argument Decoding

    private static func decodeArguments(_ json: String) throws -> [String: LumiJSONValue] {
        guard let data = json.data(using: .utf8), !data.isEmpty else { return [:] }
        return try JSONDecoder().decode([String: LumiJSONValue].self, from: data)
    }

    // MARK: - ToolManaging Execution

    public func tool(named name: String) -> (any LumiAgentTool)? {
        registeredTools[name]
    }

    public func execute(_ toolCall: LumiToolCall, conversationID: UUID) async -> LumiToolResult {
        guard let tool = registeredTools[toolCall.name] else {
            return LumiToolResult(content: "Tool not found: \(toolCall.name)", isError: true)
        }

        let startedAt = Date()
        let executionState = LumiToolExecutionContextState(
            conversationID: conversationID,
            toolCallID: toolCall.id,
            toolName: toolCall.name
        )
        do {
            let arguments = try Self.decodeArguments(toolCall.arguments)
            guard let kernel else {
                return LumiToolResult(
                    content: "Tool execution failed: kernel is not configured",
                    duration: Date().timeIntervalSince(startedAt),
                    isError: true
                )
            }
            let output = try await kernel.withToolExecutionContextState(executionState) {
                try await tool.execute(arguments: arguments, kernel: kernel)
            }
            let images = executionState.collectImages()
            let duration = Date().timeIntervalSince(startedAt)
            return LumiToolResult(content: output, duration: duration, imageAttachments: images)
        } catch {
            return LumiToolResult(
                content: "Tool execution failed: \(error.localizedDescription)",
                duration: Date().timeIntervalSince(startedAt),
                isError: true
            )
        }
    }
}
