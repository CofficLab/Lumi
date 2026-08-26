import Combine
import Foundation
import KitAgentTool
import KitSuperLog
import os
import ProviderToolManager

/// PluginToolManager 自己实现的工具注册、执行、授权和调用记录管理。
@MainActor
public final class ToolManager: ToolManagerProviding, ObservableObject, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.tool-manager", category: "ToolManager")
    public nonisolated static let emoji = "🛠️"
    nonisolated static let verbose = false

    private var recordStoreValue: ToolCallRecordStore? {
        didSet {
            guard let recordStoreValue, oldValue !== recordStoreValue else { return }
            Task { await recordStoreValue.startFlushTask() }
        }
    }

    private var registeredTools: [String: any SuperAgentTool] = [:]
    private var toolOrder: [String] = []
    private var pluginToolIndex: [String: [String]] = [:]
    private var pluginOrder: [String] = []
    private var resultCache: [String: ToolCallResult] = [:]
    private var resultCacheConversationIDs: [String: UUID] = [:]
    private var deletedConversationIDs: Set<UUID> = []
    private let eventManager = ToolManagerEventManager()

    public var recordStore: ProviderToolManager.ToolCallRecordStore? {
        get { recordStoreValue }
        set { recordStoreValue = newValue }
    }

    public init() {}

    @discardableResult
    public func addToolManagerObserver(_ callback: @escaping (ToolManagerEvent) -> Void) -> any ToolManagerObserverHandle {
        eventManager.addObserver(callback)
    }

    public func registerBuiltinTools() {
        add(ListDirectoryTool(), pluginID: Self.toolManagerPluginID)
        add(GlobTool(), pluginID: Self.toolManagerPluginID)
        add(ReadFileTool(), pluginID: Self.toolManagerPluginID)
        add(WriteFileTool(), pluginID: Self.toolManagerPluginID)
        add(EditFileTool(), pluginID: Self.toolManagerPluginID)
        add(ReadImageTool(), pluginID: Self.toolManagerPluginID)
        add(ShellTool(), pluginID: Self.toolManagerPluginID)
    }

    public static let toolManagerPluginID = "com.coffic.lumi.plugin.tool-manager"

    public func allTools() -> [any SuperAgentTool] { toolOrder.compactMap { registeredTools[$0] } }

    public func add(_ tool: any SuperAgentTool, pluginID: String) {
        if registeredTools[tool.name] == nil { toolOrder.append(tool.name) }
        registeredTools[tool.name] = tool
        for (existingPlugin, names) in pluginToolIndex where names.contains(tool.name) {
            pluginToolIndex[existingPlugin]?.removeAll { $0 == tool.name }
        }
        if pluginToolIndex[pluginID] == nil, !pluginOrder.contains(pluginID) { pluginOrder.append(pluginID) }
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
            let tools = (pluginToolIndex[pluginID] ?? []).compactMap { registeredTools[$0] }
            return tools.isEmpty ? nil : (pluginID, tools)
        }
    }

    public func tool(named name: String) -> (any SuperAgentTool)? { registeredTools[name] }

    public func displayDescription(for toolCall: ToolCall) -> String? {
        guard let tool = registeredTools[toolCall.name], let arguments = try? ToolArgumentCoding.decode(toolCall.arguments) else { return nil }
        let description = tool.displayDescription(for: arguments).trimmingCharacters(in: .whitespacesAndNewlines)
        return description.isEmpty ? nil : description
    }

    public func riskLevel(for toolCall: ToolCall) -> CommandRiskLevel? {
        guard let tool = registeredTools[toolCall.name], let arguments = try? ToolArgumentCoding.decode(toolCall.arguments) else { return nil }
        return tool.permissionRiskLevel(arguments: arguments)
    }

    public func execute(_ toolCall: ToolCall, conversationID: UUID, turnID: UUID?) async -> ToolCallResult {
        if Self.verbose { Self.logger.debug("\(Self.t)execute tool=\(toolCall.name), conversation=\(conversationID.uuidString.prefix(8))") }
        eventManager.send(.started(conversationID: conversationID, turnID: turnID, toolCall: toolCall))

        func finish(_ result: ToolCallResult) -> ToolCallResult {
            eventManager.send(.completed(conversationID: conversationID, turnID: turnID, toolCall: toolCall, result: result))
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
        let arguments: [String: ToolArgument]
        do {
            arguments = try ToolArgumentCoding.decode(toolCall.arguments)
        } catch {
            let result = ToolCallResult(content: "Tool execution failed: \(error.localizedDescription)", isError: true, duration: Date().timeIntervalSince(startedAt))
            cache(result, for: toolCall.id, conversationID: conversationID)
            logToolCall(toolCallID: toolCall.id, toolName: tool.name, toolDisplayName: toolCall.name, turnID: turnID, conversationID: conversationID, createdAt: createdAt, startedAt: startedAt, completedAt: Date(), duration: Date().timeIntervalSince(startedAt), argumentsJSON: ToolArgumentCoding.sanitized(toolCall.arguments), resultContent: "Failed to decode arguments: \(error.localizedDescription)", result: result, resultIsError: true, riskLevel: "unknown")
            return finish(result)
        }

        do {
            let output = try await tool.executeResult(arguments: arguments)
            let duration = Date().timeIntervalSince(startedAt)
            let result = ToolCallResult(content: output.content, images: output.images, isError: output.isError, executedAt: Date(), duration: duration, awaitingUserResponse: output.awaitingUserResponse, interactionState: output.interactionState)
            cache(result, for: toolCall.id, conversationID: conversationID)
            logToolCall(toolCallID: toolCall.id, toolName: tool.name, toolDisplayName: tool.displayDescription(for: arguments), turnID: turnID, conversationID: conversationID, createdAt: createdAt, startedAt: startedAt, completedAt: Date(), duration: duration, argumentsJSON: ToolArgumentCoding.encode(arguments), resultContent: output.content, result: result, resultIsError: output.isError, riskLevel: tool.permissionRiskLevel(arguments: arguments).rawValue)
            return finish(result)
        } catch {
            let result = ToolCallResult(content: "Tool execution failed: \(error.localizedDescription)", isError: true, duration: Date().timeIntervalSince(startedAt))
            cache(result, for: toolCall.id, conversationID: conversationID)
            logToolCall(toolCallID: toolCall.id, toolName: tool.name, toolDisplayName: tool.displayDescription(for: arguments), turnID: turnID, conversationID: conversationID, createdAt: createdAt, startedAt: startedAt, completedAt: Date(), duration: Date().timeIntervalSince(startedAt), argumentsJSON: ToolArgumentCoding.encode(arguments), resultContent: error.localizedDescription, result: result, resultIsError: true, riskLevel: tool.permissionRiskLevel(arguments: arguments).rawValue)
            return finish(result)
        }
    }

    public func executeBatch(_ toolCalls: [ToolCall], policy: ToolExecutionPolicy, conversationID: UUID, turnID: UUID?) async -> [BatchToolResult] {
        if Self.verbose {
            Self.logger.info("\(Self.t)execute batch count=\(toolCalls.count), conversation=\(conversationID.uuidString.prefix(8)), policy=\(String(describing: policy))")
        }
        var results: [BatchToolResult] = []
        results.reserveCapacity(toolCalls.count)
        for toolCall in toolCalls {
            if Self.verbose {
                Self.logger.info("\(Self.t)batch tool begin id=\(toolCall.id), name=\(toolCall.name), conversation=\(conversationID.uuidString.prefix(8)), turn=\(turnID?.uuidString.prefix(8) ?? "nil")")
            }
            switch policy {
            case .blockAll:
                results.append(.blocked(reason: "Tool execution was blocked because this conversation is in Chat mode."))
            case .autoExecute:
                results.append(.executed(await execute(toolCall, conversationID: conversationID, turnID: turnID)))
            case .requireApprovalForHighRisk:
                let risk = riskLevel(for: toolCall) ?? .high
                if risk.requiresPermission { results.append(.needsApproval(riskLevel: risk)) }
                else { results.append(.executed(await execute(toolCall, conversationID: conversationID, turnID: turnID))) }
            }
        }
        if Self.verbose {
            let kinds = results.map { result -> String in
                switch result {
                case .executed: return "executed"
                case .blocked: return "blocked"
                case .needsApproval: return "needsApproval"
                }
            }
            Self.logger.info("\(Self.t)batch results prepared count=\(results.count), kinds=\(kinds)")
        }
        eventManager.send(.batchCompleted(conversationID: conversationID, turnID: turnID, toolCalls: toolCalls, results: results))
        if Self.verbose { Self.logger.info("\(Self.t)batch completed conversation=\(conversationID.uuidString.prefix(8)), results=\(results.count)") }
        return results
    }

    public func toolCalls(for turnID: UUID) async -> [ToolCallRecord] {
        guard let recordStore else { return [] }
        return await recordStore.fetchRecords(for: turnID)
    }

    public func toolCallResult(for toolCallID: String) async -> ToolCallResult? {
        if let cached = resultCache[toolCallID] { return cached }
        guard let record = await recordStore?.fetchRecord(forToolCallID: toolCallID) else { return nil }
        if let json = record.resultJSON, let data = json.data(using: .utf8), let result = try? JSONDecoder().decode(ToolCallResult.self, from: data) { return result }
        return ToolCallResult(content: record.resultContent, isError: record.resultIsError, duration: record.duration)
    }

    public func deleteToolCalls(for conversationID: UUID) async {
        deletedConversationIDs.insert(conversationID)
        if let records = await recordStore?.fetchRecords(for: conversationID) {
            for record in records { if let toolCallID = record.toolCallID { resultCache.removeValue(forKey: toolCallID) } }
        }
        resultCacheConversationIDs = resultCacheConversationIDs.filter { $0.value != conversationID }
        resultCache = resultCache.filter { resultCacheConversationIDs[$0.key] != nil }
        await recordStore?.deleteAll(for: conversationID)
    }

    private func cache(_ result: ToolCallResult, for toolCallID: String, conversationID: UUID) {
        guard !deletedConversationIDs.contains(conversationID) else { return }
        resultCache[toolCallID] = result
        resultCacheConversationIDs[toolCallID] = conversationID
    }

    private func logToolCall(toolCallID: String, toolName: String, toolDisplayName: String, turnID: UUID?, conversationID: UUID, createdAt: Date, startedAt: Date, completedAt: Date?, duration: TimeInterval?, argumentsJSON: String, resultContent: String, result: ToolCallResult, resultIsError: Bool, riskLevel: String) {
        guard let store = recordStore else { return }
        Task {
            await store.record(toolCallID: toolCallID, toolName: toolName, toolDisplayName: toolDisplayName, turnID: turnID, conversationID: conversationID, createdAt: createdAt, startedAt: startedAt, completedAt: completedAt, duration: duration, argumentsJSON: argumentsJSON, resultContent: resultContent, resultJSON: Self.encodeResult(result), resultIsError: resultIsError, riskLevel: riskLevel)
        }
    }

    private static func encodeResult(_ result: ToolCallResult) -> String? {
        guard let data = try? JSONEncoder().encode(result) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
