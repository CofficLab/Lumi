import Combine
import Foundation
import KitAgentTool
import KitSuperLog
import os
import ProviderToolManager
import ProviderConversation

private struct ToolInteractionPayload: Codable {
    let toolCallID: String
    let kind: String
    let question: String
    let options: [String]
    let mode: String
}

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

    // Execution state is shared with the same-type extension in ToolManager+Run.swift.
    var registeredTools: [String: any SuperAgentTool] = [:]
    var toolOrder: [String] = []
    var pluginToolIndex: [String: [String]] = [:]
    var pluginOrder: [String] = []
    var resultCache: [String: ToolCallResult] = [:]
    var resultCacheConversationIDs: [String: UUID] = [:]
    var deletedConversationIDs: Set<UUID> = []
    let eventManager = ToolManagerEventManager()
    let toolExecutionManager = ToolExecutionManager()
    weak var conversationManager: (any ConversationManaging)?

    public var recordStore: ProviderToolManager.ToolCallRecordStore? {
        get { recordStoreValue }
        set { recordStoreValue = newValue }
    }

    public init() {}

    @discardableResult
    public func addToolJobObserver(
        _ callback: @escaping (ToolJobEvent) -> Void
    ) -> any ToolJobObserverHandle {
        toolExecutionManager.addObserver(callback)
    }

    @discardableResult
    public func submit(
        _ toolCalls: [ToolCall],
        policy: ToolExecutionPolicy,
        conversationID: UUID,
        turnID: UUID?
    ) -> [ToolJob] {
        toolExecutionManager.submit(
            toolCalls,
            policy: policy,
            conversationID: conversationID,
            turnID: turnID,
            toolResolver: { [weak self] name in self?.registeredTools[name] }
        )
    }

    public func job(for jobID: String) -> ToolJob? {
        toolExecutionManager.job(for: jobID)
    }

    public func jobs(for turnID: UUID) -> [ToolJob] {
        toolExecutionManager.jobs(for: turnID)
    }

    public func cancelJob(_ jobID: String) {
        toolExecutionManager.cancelJob(jobID)
    }

    public func cancelJobs(forTurnID turnID: UUID) {
        toolExecutionManager.cancelJobs(forTurnID: turnID)
    }

    public func cancelJobs(forConversationID conversationID: UUID) {
        toolExecutionManager.cancelJobs(forConversationID: conversationID)
    }

    func waitForJobResult(jobID: String) async -> ToolCallResult? {
        await toolExecutionManager.waitForResult(jobID: jobID)
    }

    @discardableResult
    public func addToolManagerObserver(_ callback: @escaping (ToolManagerEvent) -> Void) -> any ToolManagerObserverHandle {
        eventManager.addObserver(callback)
    }

    public func registerBuiltinTools(
        workspaceRootProvider: @escaping @MainActor @Sendable () -> String? = { nil }
    ) {
        add(
            ListDirectoryTool(workspaceRootProvider: workspaceRootProvider),
            pluginID: Self.toolManagerPluginID
        )
        add(
            GlobTool(workspaceRootProvider: workspaceRootProvider),
            pluginID: Self.toolManagerPluginID
        )
        add(
            ReadFileTool(workspaceRootProvider: workspaceRootProvider),
            pluginID: Self.toolManagerPluginID
        )
        add(
            WriteFileTool(workspaceRootProvider: workspaceRootProvider),
            pluginID: Self.toolManagerPluginID
        )
        add(
            EditFileTool(workspaceRootProvider: workspaceRootProvider),
            pluginID: Self.toolManagerPluginID
        )
        add(ReadImageTool(), pluginID: Self.toolManagerPluginID)
        add(
            ShellTool(workspaceRootProvider: workspaceRootProvider),
            pluginID: Self.toolManagerPluginID
        )
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

    public func authorizationDecision(
        for toolCall: ToolCall,
        conversationID: UUID
    ) -> ToolAuthorizationDecision {
        // Unknown tools must reach the execution layer so the resulting
        // "Tool not found" message can be returned to the LLM. Treating an
        // unknown tool as high risk here leaves the call stuck in the
        // approval UI, which cannot build a request without a registered tool.
        guard registeredTools[toolCall.name] != nil else {
            return .autoApproved
        }
        guard let level = conversationManager?.automationLevel(for: conversationID) else {
            let risk = riskLevel(for: toolCall) ?? .high
            return risk.requiresPermission ? .requiresUserApproval : .autoApproved
        }
        switch level {
        case .chat:
            return .blocked(reason: "Tool execution was blocked because this conversation is in Chat mode.")
        case .autonomous:
            return .autoApproved
        case .build:
            let risk = riskLevel(for: toolCall) ?? .high
            return risk.requiresPermission ? .requiresUserApproval : .autoApproved
        }
    }
}
