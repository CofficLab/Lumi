import Combine
import Foundation
import KitAgentTool
import KitSuperLog
import os
import ProviderToolManager

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
    nonisolated static let verbose = true

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
}
