import Foundation
import KitAgentTool
import ProviderAgentLoop
import ProviderConversation
import ProviderLifecycleHooks
import ProviderMessage
import ProviderToolManager
@testable import PluginConversationManager
@testable import PluginSubagent

/// 子代理测试共用夹具：真实会话/消息存储 + 可注入状态的 ToolManager/AgentLoop。
@MainActor
final class SubagentTestFixture {
    let directory: URL
    let store: ConversationStore
    let manager: ConversationManager
    let messages: DefaultMessageManager
    let toolManager: SubagentToolManagerSpy
    let agentLoop: SubagentAgentLoopSpy
    let registry: SubagentRegistry

    init() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SubagentTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        store = try ConversationStore(databaseRootURL: directory)
        messages = DefaultMessageManager()
        toolManager = SubagentToolManagerSpy()
        agentLoop = SubagentAgentLoopSpy()
        manager = ConversationManager(
            store: store,
            dataDirectory: directory,
            messageManager: messages,
            toolManager: toolManager,
            agentTurn: agentLoop
        )
        registry = SubagentRegistry(
            conversations: manager,
            messages: messages,
            toolManager: toolManager,
            agentLoop: agentLoop
        )
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: directory)
    }

    @discardableResult
    func makeRoot() async throws -> UUID {
        try await manager.createConversationAndWait(
            title: "Root", projectPath: nil, modelID: nil, parentConversationID: nil
        )
    }

    @discardableResult
    func makeChild(
        of rootID: UUID,
        label: String,
        name: String?,
        jobID: String,
        createdAt: Date = Date(),
        status: ToolJobStatus = .completed
    ) async throws -> UUID {
        let bridge = SubagentConversationBridge(conversations: manager)
        let childID = try await bridge.createChildConversation(parentID: rootID, description: label)
        let payload = SubagentTimeline.Payload(
            label: label,
            parentConversationID: rootID,
            childConversationID: childID,
            jobID: jobID,
            name: name
        )
        messages.insertMessage(
            SubagentTimeline.message(conversationID: rootID, turnID: nil, payload: payload),
            to: rootID
        )
        toolManager.jobsByID[jobID] = ToolJob(
            id: jobID,
            conversationID: rootID,
            turnID: nil,
            toolCall: ToolCall(
                id: "call-\(jobID)",
                name: RunSubagentTool.toolName,
                arguments: "{\"description\":\"\(label)\",\"name\":\"\(name ?? "")\"}"
            ),
            status: status,
            createdAt: createdAt
        )
        return childID
    }
}

@MainActor
final class SubagentAgentLoopSpy: AgentLoopProviding {
    var runningConversationIDs: Set<UUID> = []
    var autoReplySuppressed: Set<UUID> = []
    var runTurnCalls: [UUID] = []
    var runTurnHandler: ((UUID) async -> AgentLoopOutcome)?

    private var observers: [UUID: (AgentLoopEvent) -> Void] = [:]

    func addAgentLoopObserver(_ callback: @escaping (AgentLoopEvent) -> Void) -> any AgentLoopObserverHandle {
        let id = UUID()
        observers[id] = callback
        return SubagentAgentLoopObserverHandle { [weak self] in
            self?.observers.removeValue(forKey: id)
        }
    }

    func emit(_ event: AgentLoopEvent) {
        for callback in observers.values {
            callback(event)
        }
    }

    func runTurn(in conversationID: UUID) async throws -> AgentLoopOutcome {
        runTurnCalls.append(conversationID)
        runningConversationIDs.insert(conversationID)
        defer { runningConversationIDs.remove(conversationID) }
        if let runTurnHandler {
            return await runTurnHandler(conversationID)
        }
        return .completed
    }

    func resumeTurn(in conversationID: UUID, request: AgentTurnResumeRequest) async throws -> AgentLoopOutcome {
        .completed
    }
    func cancelTurn(in conversationID: UUID) { runningConversationIDs.remove(conversationID) }
    func state(for conversationID: UUID) -> AgentLoopState {
        runningConversationIDs.contains(conversationID) ? .running : .idle
    }
    func suspension(for conversationID: UUID) -> AgentLoopSuspension? { nil }
    func isRunning(for conversationID: UUID) -> Bool { runningConversationIDs.contains(conversationID) }
    func currentTurnID(for conversationID: UUID) -> UUID? { nil }
    func isAutoReplySuppressed(for conversationID: UUID) -> Bool { autoReplySuppressed.contains(conversationID) }
    func setAutoReplySuppressed(_ suppressed: Bool, for conversationID: UUID) {
        if suppressed {
            autoReplySuppressed.insert(conversationID)
        } else {
            autoReplySuppressed.remove(conversationID)
        }
    }
    func setLifecycleHooks(_ hooks: (any LifecycleHooksProviding)?) {}
}

private final class SubagentAgentLoopObserverHandle: AgentLoopObserverHandle {
    private let onCancel: () -> Void
    init(onCancel: @escaping () -> Void) { self.onCancel = onCancel }
    func cancel() { onCancel() }
}

@MainActor
final class SubagentToolManagerSpy: ToolManagerProviding {
    var jobsByID: [String: ToolJob] = [:]
    private var jobObservers: [UUID: (ToolJobEvent) -> Void] = [:]

    func emit(_ event: ToolJobEvent) {
        for callback in jobObservers.values {
            callback(event)
        }
    }

    func jobs(forConversationID conversationID: UUID) -> [ToolJob] {
        jobsByID.values
            .filter { $0.conversationID == conversationID }
            .sorted { $0.createdAt < $1.createdAt }
    }

    func job(for jobID: String) -> ToolJob? {
        jobsByID[jobID]
    }

    func addToolManagerObserver(_ callback: @escaping (ToolManagerEvent) -> Void) -> any ToolManagerObserverHandle {
        SubagentToolManagerObserverHandle()
    }
    func addToolJobObserver(_ callback: @escaping (ToolJobEvent) -> Void) -> any ToolJobObserverHandle {
        let id = UUID()
        jobObservers[id] = callback
        return SubagentToolManagerObserverHandle { [weak self] in
            self?.jobObservers.removeValue(forKey: id)
        }
    }
    func allTools() -> [any SuperAgentTool] { [] }
    func add(_ tool: any SuperAgentTool, pluginID: String) {}
    func remove(id: String) {}
    func toolsGroupedByPlugin() -> [(pluginID: String, tools: [any SuperAgentTool])] { [] }
    func tool(named name: String) -> (any SuperAgentTool)? { nil }
    func displayDescription(for toolCall: ToolCall) -> String? { nil }
    func riskLevel(for toolCall: ToolCall) -> CommandRiskLevel? { nil }
    func execute(_ toolCall: ToolCall, conversationID: UUID, turnID: UUID?) async -> ToolCallResult {
        ToolCallResult(content: "")
    }
    func toolCalls(for turnID: UUID) async -> [ToolCallRecord] { [] }
    func toolCallResult(for toolCallID: String) async -> ToolCallResult? { nil }
    func deleteToolCalls(for conversationID: UUID) async {}
}

private final class SubagentToolManagerObserverHandle: ToolManagerObserverHandle, ToolJobObserverHandle {
    private let onCancel: () -> Void
    init(onCancel: @escaping () -> Void = {}) { self.onCancel = onCancel }
    func cancel() { onCancel() }
}

/// 轮询等待异步状态，超时抛错。
@MainActor
func subagentWaitUntil(
    timeout: TimeInterval = 5,
    _ condition: @MainActor () async -> Bool
) async throws {
    struct TimeoutError: Error {}
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if await condition() { return }
        try await Task.sleep(nanoseconds: 20_000_000)
    }
    throw TimeoutError()
}
