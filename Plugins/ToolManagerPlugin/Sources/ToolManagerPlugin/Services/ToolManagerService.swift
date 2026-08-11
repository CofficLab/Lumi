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

    /// Fast path for results produced during the current process. Persistence is
    /// asynchronous, so the UI can resolve a freshly completed call immediately.
    private var resultCache: [String: LumiToolResult] = [:]
    private var resultCacheConversationIDs: [String: UUID] = [:]
    private var deletedConversationIDs: Set<UUID> = []

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

    public func displayDescription(for toolCall: LumiToolCall) -> String? {
        guard let tool = registeredTools[toolCall.name],
              let data = toolCall.arguments.data(using: .utf8),
              let arguments = try? JSONDecoder().decode([String: LumiJSONValue].self, from: data)
        else {
            return nil
        }

        let description = tool.displayDescription(arguments: arguments)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return description.isEmpty ? nil : description
    }

    public func riskLevel(for toolCall: LumiToolCall) -> LumiCommandRiskLevel? {
        guard let kernel,
              let tool = registeredTools[toolCall.name],
              let arguments = try? Self.decodeArguments(toolCall.arguments)
        else {
            return nil
        }
        return tool.riskLevel(arguments: arguments, kernel: kernel)
    }

    public func execute(
        _ toolCall: LumiToolCall,
        conversationID: UUID,
        turnID: UUID?
    ) async -> LumiToolResult {
        guard !deletedConversationIDs.contains(conversationID) else {
            return LumiToolResult(content: "Conversation was deleted", isError: true)
        }
        guard let tool = registeredTools[toolCall.name] else {
            let result = LumiToolResult(content: "Tool not found: \(toolCall.name)", isError: true)
            cache(result, for: toolCall.id, conversationID: conversationID)
            return result
        }

        let startedAt = Date()
        let createdAt = Date()
        guard let kernel else {
            let result = LumiToolResult(
                content: "Tool execution failed: kernel is not configured",
                duration: Date().timeIntervalSince(startedAt),
                isError: true
            )
            cache(result, for: toolCall.id, conversationID: conversationID)
            return result
        }
        let currentProjectPath = kernel.project?.currentProject?.path
        let resolvedTurnID = turnID ?? kernel.turnID
        let executionState = LumiToolExecutionContextState(
            conversationID: conversationID,
            toolCallID: toolCall.id,
            toolName: toolCall.name,
            turnID: resolvedTurnID,
            currentProjectPath: currentProjectPath
        )

        // 预先解码参数(失败时用于日志记录)
        let arguments: [String: LumiJSONValue]
        do {
            arguments = try Self.decodeArguments(toolCall.arguments)
        } catch {
            let result = LumiToolResult(
                content: "Tool execution failed: \(error.localizedDescription)",
                duration: Date().timeIntervalSince(startedAt),
                isError: true
            )
            cache(result, for: toolCall.id, conversationID: conversationID)
            // 记录解码失败
            logToolCall(
                toolCallID: toolCall.id,
                toolName: tool.name,
                toolDisplayName: toolCall.name,
                turnID: resolvedTurnID,
                conversationID: conversationID,
                createdAt: createdAt,
                startedAt: startedAt,
                completedAt: Date(),
                duration: Date().timeIntervalSince(startedAt),
                argumentsJSON: toolCall.arguments,
                resultContent: "Failed to decode arguments: \(error.localizedDescription)",
                result: result,
                resultIsError: true,
                riskLevel: "unknown",
                turnControl: nil
            )
            return result
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
            let result = LumiToolResult(
                content: "Tool execution failed: \(error.localizedDescription)",
                duration: Date().timeIntervalSince(startedAt),
                isError: true
            )
            cache(result, for: toolCall.id, conversationID: conversationID)
            // 记录失败的调用
            logToolCall(
                toolCallID: toolCall.id,
                toolName: tool.name,
                toolDisplayName: tool.displayDescription(arguments: arguments),
                turnID: resolvedTurnID,
                conversationID: conversationID,
                createdAt: createdAt,
                startedAt: startedAt,
                completedAt: Date(),
                duration: Date().timeIntervalSince(startedAt),
                argumentsJSON: Self.encodeArguments(arguments),
                resultContent: error.localizedDescription,
                result: result,
                resultIsError: true,
                riskLevel: tool.riskLevel(arguments: arguments, kernel: kernel).rawValue,
                turnControl: nil
            )
            return result
        }

        let images = executionState.collectImages()
        let result = LumiToolResult(
            content: executionResult.content,
            duration: duration,
            isError: executionResult.isError,
            imageAttachments: images,
            turnControl: executionResult.turnControl
        )
        cache(result, for: toolCall.id, conversationID: conversationID)

        // 记录成功的调用(后台异步，不阻塞主流程)
        logToolCall(
            toolCallID: toolCall.id,
            toolName: tool.name,
            toolDisplayName: tool.displayDescription(arguments: arguments),
            turnID: resolvedTurnID,
            conversationID: conversationID,
            createdAt: createdAt,
            startedAt: startedAt,
            completedAt: Date(),
            duration: duration,
            argumentsJSON: Self.encodeArguments(arguments),
            resultContent: executionResult.content,
            result: result,
            resultIsError: executionResult.isError,
            riskLevel: tool.riskLevel(arguments: arguments, kernel: kernel).rawValue,
            turnControl: Self.encodeTurnControl(executionResult.turnControl)
        )

        return result
    }

    public func toolCalls(for turnID: UUID) async -> [LumiToolCallRecord] {
        guard let records = await recordStore?.fetchRecords(forTurnID: turnID) else { return [] }
        return records.map {
            LumiToolCallRecord(
                id: $0.id,
                turnID: $0.turnID,
                toolName: $0.toolName,
                toolDisplayName: $0.toolDisplayName,
                conversationID: UUID(uuidString: $0.conversationID) ?? UUID(),
                createdAt: $0.createdAt,
                startedAt: $0.startedAt,
                completedAt: $0.completedAt,
                duration: $0.duration,
                argumentsJSON: $0.argumentsJSON,
                resultContent: $0.resultContent,
                resultIsError: $0.resultIsError,
                riskLevel: $0.riskLevel,
                turnControl: $0.turnControl
            )
        }
    }

    /// Query one tool result by the original `LumiToolCall.id`.
    public func toolCallResult(for toolCallID: String) async -> LumiToolResult? {
        if let cached = resultCache[toolCallID] {
            return cached
        }
        guard let record = await recordStore?.fetchRecord(forToolCallID: toolCallID) else {
            return nil
        }

        if let resultJSON = record.resultJSON,
           let data = resultJSON.data(using: .utf8),
           let result = try? JSONDecoder().decode(LumiToolResult.self, from: data) {
            return result
        }

        // Backward compatibility for records created before full result snapshots
        // were added. These records can still provide their text result.
        return LumiToolResult(
            content: record.resultContent,
            duration: record.duration,
            isError: record.resultIsError
        )
    }

    public func deleteToolCalls(for conversationID: UUID) async {
        deletedConversationIDs.insert(conversationID)
        // Remove transient results as well as the persisted execution log.
        if let records = await recordStore?.fetchRecords(for: conversationID) {
            for record in records {
                if let toolCallID = record.toolCallID {
                    resultCache.removeValue(forKey: toolCallID)
                }
            }
        }
        resultCacheConversationIDs = resultCacheConversationIDs.filter { $0.value != conversationID }
        resultCache = resultCache.filter { resultCacheConversationIDs[$0.key] != nil }
        await recordStore?.deleteAll(for: conversationID)
    }

    private func cache(_ result: LumiToolResult, for toolCallID: String, conversationID: UUID) {
        guard !deletedConversationIDs.contains(conversationID) else { return }
        resultCache[toolCallID] = result
        resultCacheConversationIDs[toolCallID] = conversationID
    }

    // MARK: - Tool Call Logging

    /// 后台异步记录工具调用，不阻塞主流程。
    private func logToolCall(
        toolCallID: String,
        toolName: String,
        toolDisplayName: String,
        turnID: UUID?,
        conversationID: UUID,
        createdAt: Date,
        startedAt: Date,
        completedAt: Date?,
        duration: TimeInterval?,
        argumentsJSON: String,
        resultContent: String,
        result: LumiToolResult,
        resultIsError: Bool,
        riskLevel: String,
        turnControl: String?
    ) {
        // 捕获必要的信息到值类型，避免引用 kernel 等复杂对象
        let store = recordStore
        let eventManager = kernel?.eventManager

        // 后台异步记录，不 await，不阻塞
        Task {
            await store?.record(
                toolCallID: toolCallID,
                toolName: toolName,
            toolDisplayName: toolDisplayName,
            turnID: turnID,
                conversationID: conversationID,
                createdAt: createdAt,
                startedAt: startedAt,
                completedAt: completedAt,
                duration: duration,
                argumentsJSON: argumentsJSON,
                resultContent: resultContent,
                resultJSON: Self.encodeResult(result),
                resultIsError: resultIsError,
                riskLevel: riskLevel,
                turnControl: turnControl
            )
            eventManager?.post(
                .toolActivityDidChange,
                userInfo: [
                    "conversationID": conversationID
                ]
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

    private static func encodeResult(_ result: LumiToolResult) -> String? {
        guard let data = try? JSONEncoder().encode(result) else { return nil }
        return String(data: data, encoding: .utf8)
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
