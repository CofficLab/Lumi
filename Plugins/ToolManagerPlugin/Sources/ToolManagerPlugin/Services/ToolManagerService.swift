import Foundation
import LumiKernel

/// Agent 工具服务实现
@MainActor
public final class ToolManagerService: ToolManaging {

    /// Kernel 引用，用于在执行工具时直接传递给工具
    public weak var kernel: LumiKernel?

    /// 工具调用记录存储(后台异步写入，不影响主流程)。
    /// 由 OnBoot 钩子初始化。
    var recordStore: ToolCallRecordStore?

    /// 已注册的工具
    private var registeredTools: [String: any LumiAgentTool] = [:]

    /// 工具注册顺序
    private var toolOrder: [String] = []

    /// 工具归属插件的反向索引：pluginID -> [tool.name]
    /// 用于状态栏「可用工具」按插件分组展示。
    private var pluginToolIndex: [String: [String]] = [:]

    /// 插件首次出现顺序，决定分组在 UI 中的排列。
    private var pluginOrder: [String] = []

    /// 已注册的子 Agent 定义，独立于可执行的 delegate 工具保存，供 UI 和调试查询。
    private var registeredSubAgents: [String: LumiSubAgentDefinition] = [:]
    private var subAgentOrder: [String] = []

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
        subAgentOrder.compactMap { registeredSubAgents[$0] }
    }

    public func addSubAgent(_ subAgent: LumiSubAgentDefinition) {
        let key = subAgent.routingID
        if registeredSubAgents[key] == nil {
            subAgentOrder.append(key)
        }
        registeredSubAgents[key] = subAgent
    }

    public func removeAllSubAgents() {
        registeredSubAgents.removeAll()
        subAgentOrder.removeAll()
    }

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
        let createdAt = Date()
        guard let kernel else {
            return LumiToolResult(
                content: "Tool execution failed: kernel is not configured",
                duration: Date().timeIntervalSince(startedAt),
                isError: true
            )
        }
        let currentProjectPath = kernel.project?.currentProject?.path
        let executionState = LumiToolExecutionContextState(
            conversationID: conversationID,
            toolCallID: toolCall.id,
            toolName: toolCall.name,
            currentProjectPath: currentProjectPath
        )

        // 预先解码参数(失败时用于日志记录)
        let arguments: [String: LumiJSONValue]
        do {
            arguments = try Self.decodeArguments(toolCall.arguments)
        } catch {
            // 记录解码失败
            logToolCall(
                toolName: tool.name,
                toolDisplayName: toolCall.name,
                conversationID: conversationID,
                createdAt: createdAt,
                startedAt: startedAt,
                completedAt: Date(),
                duration: Date().timeIntervalSince(startedAt),
                argumentsJSON: toolCall.arguments,
                resultContent: "Failed to decode arguments: \(error.localizedDescription)",
                resultIsError: true,
                riskLevel: "unknown",
                turnControl: nil
            )
            return LumiToolResult(
                content: "Tool execution failed: \(error.localizedDescription)",
                duration: Date().timeIntervalSince(startedAt),
                isError: true
            )
        }

        let executionResult: LumiToolExecutionResult
        let duration: TimeInterval

        do {
            let result = try await kernel.withToolExecutionContextState(executionState) {
                try await tool.executeResult(arguments: arguments, kernel: kernel)
            }
            executionResult = result
            duration = Date().timeIntervalSince(startedAt)
        } catch {
            // 记录失败的调用
            logToolCall(
                toolName: tool.name,
                toolDisplayName: tool.displayDescription(arguments: arguments),
                conversationID: conversationID,
                createdAt: createdAt,
                startedAt: startedAt,
                completedAt: Date(),
                duration: Date().timeIntervalSince(startedAt),
                argumentsJSON: Self.encodeArguments(arguments),
                resultContent: error.localizedDescription,
                resultIsError: true,
                riskLevel: tool.riskLevel(arguments: arguments, kernel: kernel).rawValue,
                turnControl: nil
            )
            return LumiToolResult(
                content: "Tool execution failed: \(error.localizedDescription)",
                duration: Date().timeIntervalSince(startedAt),
                isError: true
            )
        }

        let images = executionState.collectImages()
        let result = LumiToolResult(
            content: executionResult.content,
            duration: duration,
            isError: executionResult.isError,
            imageAttachments: images,
            turnControl: executionResult.turnControl
        )

        // 记录成功的调用(后台异步，不阻塞主流程)
        logToolCall(
            toolName: tool.name,
            toolDisplayName: tool.displayDescription(arguments: arguments),
            conversationID: conversationID,
            createdAt: createdAt,
            startedAt: startedAt,
            completedAt: Date(),
            duration: duration,
            argumentsJSON: Self.encodeArguments(arguments),
            resultContent: executionResult.content,
            resultIsError: executionResult.isError,
            riskLevel: tool.riskLevel(arguments: arguments, kernel: kernel).rawValue,
            turnControl: Self.encodeTurnControl(executionResult.turnControl)
        )

        return result
    }

    // MARK: - Tool Call Logging

    /// 后台异步记录工具调用，不阻塞主流程。
    private func logToolCall(
        toolName: String,
        toolDisplayName: String,
        conversationID: UUID,
        createdAt: Date,
        startedAt: Date,
        completedAt: Date?,
        duration: TimeInterval?,
        argumentsJSON: String,
        resultContent: String,
        resultIsError: Bool,
        riskLevel: String,
        turnControl: String?
    ) {
        // 捕获必要的信息到值类型，避免引用 kernel 等复杂对象
        let store = recordStore

        // 后台异步记录，不 await，不阻塞
        Task {
            await store?.record(
                toolName: toolName,
                toolDisplayName: toolDisplayName,
                conversationID: conversationID,
                createdAt: createdAt,
                startedAt: startedAt,
                completedAt: completedAt,
                duration: duration,
                argumentsJSON: argumentsJSON,
                resultContent: resultContent,
                resultIsError: resultIsError,
                riskLevel: riskLevel,
                turnControl: turnControl
            )
        }
    }

    /// 将参数字典编码为 JSON 字符串。
    private static func encodeArguments(_ arguments: [String: LumiJSONValue]) -> String {
        guard let data = try? JSONEncoder().encode(arguments),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }

    /// 将 TurnControl 编码为字符串。
    private static func encodeTurnControl(_ control: AgentTurnControl) -> String? {
        switch control {
        case .continueTurn:
            return nil
        case .suspend(let suspension):
            return "suspend:\(suspension.suspensionID)"
        case .resumed(let suspension, let answer):
            return "resumed:\(suspension.suspensionID):\(answer.prefix(100))"
        }
    }
}
