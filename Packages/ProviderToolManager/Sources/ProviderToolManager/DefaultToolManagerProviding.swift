import KitAgentTool
import Combine
import Foundation
import KitSuperLog
import os

/// `ToolManagerProviding` 的默认实现。
@MainActor
public final class DefaultToolManagerProviding: ToolManagerProviding, ObservableObject, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.provider-tool-manager", category: "ToolManager")
    public nonisolated static let emoji = "🛠️"

    /// 工具调用记录存储（后台异步写入，不影响主流程）。
    /// 由宿主在装配阶段设置；未设置时记录功能 no-op。
    /// 设置后自动启动定时落盘任务。
    public var recordStore: ToolCallRecordStore? {
        didSet {
            guard let recordStore, oldValue !== recordStore else { return }
            Task { await recordStore.startFlushTask() }
        }
    }

    /// 已注册的工具，按名称索引。
    private var registeredTools: [String: any SuperAgentTool] = [:]

    /// 工具注册顺序。
    private var toolOrder: [String] = []

    /// 工具归属插件的反向索引：pluginID -> [tool.name]。
    private var pluginToolIndex: [String: [String]] = [:]

    /// 插件首次出现顺序，决定分组在 UI 中的排列。
    private var pluginOrder: [String] = []

    /// 当前进程内产生的结果 fast path：持久化是异步的，
    /// UI 需要能立即解析刚完成的调用结果。
    private var resultCache: [String: ToolCallResult] = [:]
    private var resultCacheConversationIDs: [String: UUID] = [:]
    private var deletedConversationIDs: Set<UUID> = []
    private var toolManagerObservers: [UUID: (ToolManagerEvent) -> Void] = [:]

    public init() {}

    @discardableResult
    public func addToolManagerObserver(
        _ callback: @escaping (ToolManagerEvent) -> Void
    ) -> any ToolManagerObserverHandle {
        let id = UUID()
        toolManagerObservers[id] = callback
        return DefaultToolManagerObserverHandle { [weak self] in
            self?.toolManagerObservers.removeValue(forKey: id)
        }
    }

    private func notify(_ event: ToolManagerEvent) {
        for callback in toolManagerObservers.values {
            callback(event)
        }
    }

    // MARK: - Registration

    public func allTools() -> [any SuperAgentTool] {
        toolOrder.compactMap { registeredTools[$0] }
    }

    public func add(_ tool: any SuperAgentTool, pluginID: String) {
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

        objectWillChange.send()
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

        objectWillChange.send()
    }

    public func toolsGroupedByPlugin() -> [(pluginID: String, tools: [any SuperAgentTool])] {
        pluginOrder.compactMap { pluginID in
            let names = pluginToolIndex[pluginID] ?? []
            let tools = names.compactMap { registeredTools[$0] }
            return tools.isEmpty ? nil : (pluginID, tools)
        }
    }

    // MARK: - Execution

    public func tool(named name: String) -> (any SuperAgentTool)? {
        registeredTools[name]
    }

    public func displayDescription(for toolCall: ToolCall) -> String? {
        guard let tool = registeredTools[toolCall.name],
              let arguments = try? ToolArgumentCoding.decode(toolCall.arguments)
        else {
            return nil
        }
        let description = tool.displayDescription(for: arguments)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return description.isEmpty ? nil : description
    }

    public func riskLevel(for toolCall: ToolCall) -> CommandRiskLevel? {
        guard let tool = registeredTools[toolCall.name],
              let arguments = try? ToolArgumentCoding.decode(toolCall.arguments)
        else {
            return nil
        }
        return tool.permissionRiskLevel(arguments: arguments)
    }

    public func execute(
        _ toolCall: ToolCall,
        conversationID: UUID,
        turnID: UUID?
    ) async -> ToolCallResult {
        Self.logger.debug("\(Self.t)execute tool=\(toolCall.name), conversation=\(conversationID.uuidString.prefix(8))")
        notify(.started(conversationID: conversationID, turnID: turnID, toolCall: toolCall))

        func finish(_ result: ToolCallResult) -> ToolCallResult {
            notify(.completed(
                conversationID: conversationID,
                turnID: turnID,
                toolCall: toolCall,
                result: result
            ))
            return result
        }

        guard !deletedConversationIDs.contains(conversationID) else {
            let result = ToolCallResult(content: "Conversation was deleted", isError: true)
            cache(result, for: toolCall.id, conversationID: conversationID)
            return finish(result)
        }
        guard let tool = registeredTools[toolCall.name] else {
            let result = ToolCallResult(content: "Tool not found: \(toolCall.name)", isError: true)
            cache(result, for: toolCall.id, conversationID: conversationID)
            return finish(result)
        }

        let startedAt = Date()
        let createdAt = Date()

        // 预先解码参数（失败时用于日志记录）
        let arguments: [String: ToolArgument]
        do {
            arguments = try ToolArgumentCoding.decode(toolCall.arguments)
        } catch {
            let result = ToolCallResult(
                content: "Tool execution failed: \(error.localizedDescription)",
                isError: true,
                duration: Date().timeIntervalSince(startedAt)
            )
            cache(result, for: toolCall.id, conversationID: conversationID)
            logToolCall(
                toolCallID: toolCall.id,
                toolName: tool.name,
                toolDisplayName: toolCall.name,
                turnID: turnID,
                conversationID: conversationID,
                createdAt: createdAt,
                startedAt: startedAt,
                completedAt: Date(),
                duration: Date().timeIntervalSince(startedAt),
                argumentsJSON: ToolArgumentCoding.sanitized(toolCall.arguments),
                resultContent: "Failed to decode arguments: \(error.localizedDescription)",
                result: result,
                resultIsError: true,
                riskLevel: "unknown"
            )
            return finish(result)
        }

        let executionContent: String
        let executionImages: [ImageAttachment]
        let duration: TimeInterval
        let isError: Bool
        let awaitingUserResponse: Bool
        let interactionState: ToolCallInteractionState?

        do {
            let toolResult = try await tool.executeResult(arguments: arguments)
            executionContent = toolResult.content
            executionImages = toolResult.images
            duration = Date().timeIntervalSince(startedAt)
            isError = toolResult.isError
            // 透传挂起语义：AskUser 等工具返回 awaitingUserResponse 让
            // Agent 循环暂停等待用户回答。
            awaitingUserResponse = toolResult.awaitingUserResponse
            interactionState = toolResult.interactionState
        } catch {
            let result = ToolCallResult(
                content: "Tool execution failed: \(error.localizedDescription)",
                isError: true,
                duration: Date().timeIntervalSince(startedAt)
            )
            cache(result, for: toolCall.id, conversationID: conversationID)
            logToolCall(
                toolCallID: toolCall.id,
                toolName: tool.name,
                toolDisplayName: tool.displayDescription(for: arguments),
                turnID: turnID,
                conversationID: conversationID,
                createdAt: createdAt,
                startedAt: startedAt,
                completedAt: Date(),
                duration: Date().timeIntervalSince(startedAt),
                argumentsJSON: ToolArgumentCoding.encode(arguments),
                resultContent: error.localizedDescription,
                result: result,
                resultIsError: true,
                riskLevel: tool.permissionRiskLevel(arguments: arguments).rawValue
            )
            return finish(result)
        }

        let result = ToolCallResult(
            content: executionContent,
            images: executionImages,
            isError: isError,
            executedAt: Date(),
            duration: duration,
            awaitingUserResponse: awaitingUserResponse,
            interactionState: interactionState
        )
        cache(result, for: toolCall.id, conversationID: conversationID)

        // 记录成功的调用（后台异步，不阻塞主流程）
        logToolCall(
            toolCallID: toolCall.id,
            toolName: tool.name,
            toolDisplayName: tool.displayDescription(for: arguments),
            turnID: turnID,
            conversationID: conversationID,
            createdAt: createdAt,
            startedAt: startedAt,
            completedAt: Date(),
            duration: duration,
            argumentsJSON: ToolArgumentCoding.encode(arguments),
            resultContent: executionContent,
            result: result,
            resultIsError: isError,
            riskLevel: tool.permissionRiskLevel(arguments: arguments).rawValue
        )

        return finish(result)
    }

    public func executeBatch(
        _ toolCalls: [ToolCall],
        policy: ToolExecutionPolicy,
        conversationID: UUID,
        turnID: UUID?
    ) async -> [BatchToolResult] {
        Self.logger.info("\(Self.t)execute batch count=\(toolCalls.count), conversation=\(conversationID.uuidString.prefix(8)), policy=\(String(describing: policy))")
        var results: [BatchToolResult] = []
        results.reserveCapacity(toolCalls.count)
        for toolCall in toolCalls {
            switch policy {
            case .blockAll:
                results.append(.blocked(reason: "Tool execution was blocked because this conversation is in Chat mode."))
            case .autoExecute:
                results.append(.executed(await execute(toolCall, conversationID: conversationID, turnID: turnID)))
            case .requireApprovalForHighRisk:
                let risk = riskLevel(for: toolCall) ?? .high
                if risk.requiresPermission {
                    results.append(.needsApproval(riskLevel: risk))
                } else {
                    results.append(.executed(await execute(toolCall, conversationID: conversationID, turnID: turnID)))
                }
            }
        }
        notify(.batchCompleted(conversationID: conversationID, turnID: turnID, toolCalls: toolCalls, results: results))
        Self.logger.info("\(Self.t)batch completed conversation=\(conversationID.uuidString.prefix(8)), results=\(results.count)")
        return results
    }

    // MARK: - Records

    public func toolCalls(for turnID: UUID) async -> [ToolCallRecord] {
        guard let recordStore else { return [] }
        return await recordStore.fetchRecords(forTurnID: turnID)
    }

    /// 按原始 `ToolCall.id` 查询一次调用的结果。
    public func toolCallResult(for toolCallID: String) async -> ToolCallResult? {
        if let cached = resultCache[toolCallID] {
            return cached
        }
        guard let record = await recordStore?.fetchRecord(forToolCallID: toolCallID) else {
            return nil
        }

        if let resultJSON = record.resultJSON,
           let data = resultJSON.data(using: .utf8),
           let result = try? JSONDecoder().decode(ToolCallResult.self, from: data) {
            return result
        }

        // 兼容未写入完整结果快照的早期记录：仍可提供文本结果。
        return ToolCallResult(
            content: record.resultContent,
            isError: record.resultIsError,
            duration: record.duration
        )
    }

    public func deleteToolCalls(for conversationID: UUID) async {
        deletedConversationIDs.insert(conversationID)
        // 清理瞬时结果与持久化执行日志。
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

    // MARK: - Result Cache

    private func cache(_ result: ToolCallResult, for toolCallID: String, conversationID: UUID) {
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
        result: ToolCallResult,
        resultIsError: Bool,
        riskLevel: String
    ) {
        guard let store = recordStore else { return }
        Task {
            await store.record(
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
                riskLevel: riskLevel
            )
        }
    }

    /// 将 `ToolCallResult` 编码为 JSON 字符串（记录用）。
    private static func encodeResult(_ result: ToolCallResult) -> String? {
        guard let data = try? JSONEncoder().encode(result) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
