import Foundation
import KitAgentTool
import KitLLM
import ProviderAgentLoop
import ProviderConversation
import ProviderLifecycleHooks
import ProviderMessage
import ProviderProject
import ProviderToolManager
import Testing
@testable import PluginConversationManager
@testable import PluginSubagent

/// #1313 Task 1：子代理委托的隐藏子会话契约。
///
/// 子会话以 `parentConversationID` 标记归属，必须满足：
/// - 不进入会话列表、不改变选中、不发 `.created`；
/// - 继承父会话的项目绑定（含「明确不绑定」）、模型与自动化等级；
/// - 消息与父会话完全隔离；
/// - 删除父会话时连带取消回合、清消息、删工具记录、删库行。
@MainActor
@Suite(.serialized)
struct SubagentChildConversationTests {

    // MARK: - 隐藏与继承

    @Test("子会话不进入列表、不改变选中、不发 created 事件")
    func childIsHiddenFromListAndKeepsSelection() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let manager = fixture.manager
        let rootID = try await manager.createConversationAndWait(
            title: "Root", projectPath: nil, modelID: nil, parentConversationID: nil
        )
        var events: [ConversationEvent] = []
        let handle = manager.addConversationObserver { events.append($0) }
        defer { handle.cancel() }

        let bridge = SubagentConversationBridge(conversations: manager)
        let childID = try await bridge.createChildConversation(
            parentID: rootID, description: "Explore the codebase"
        )

        #expect(manager.conversations.map(\.id) == [rootID])
        #expect(manager.selectedConversationID == rootID)
        #expect(!events.contains(.created(childID)))
        let child = await fixture.store.fetchConversation(id: childID)
        #expect(child?.parentConversationID == rootID)
    }

    @Test("子会话继承父会话的项目、模型与自动化等级")
    func childInheritsParentProjectModelAndAutomation() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let manager = fixture.manager
        let modelID = try #require(LLMModelID(providerID: "openai", modelID: "gpt-4o")?.rawValue)
        manager.setGlobalAutomationLevel(.chat)
        let rootID = try await manager.createConversationAndWait(
            title: "Root",
            projectPath: "/tmp/subagent-parent-project",
            modelID: modelID,
            parentConversationID: nil
        )
        manager.setAutomationLevel(.autonomous, for: rootID)

        let bridge = SubagentConversationBridge(conversations: manager)
        let childID = try await bridge.createChildConversation(parentID: rootID, description: "child")

        let child = try #require(await manager.fetchConversation(id: childID))
        #expect(child.projectPath == "/tmp/subagent-parent-project")
        #expect(child.modelID == modelID)
        #expect(child.parentConversationID == rootID)
        #expect(manager.automationLevel(for: childID) == .autonomous)
    }

    @Test("父会话明确不绑定项目时，子会话不回退到当前项目")
    func unboundParentDoesNotBindChildToCurrentProject() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let project = ProjectSpy()
        project.currentProject = ProjectInfo(name: "Current", path: "/tmp/subagent-current-project")
        let manager = ConversationManager(
            store: fixture.store, dataDirectory: fixture.directory, project: project
        )
        let rootID = try await manager.createConversationAndWait(
            title: "Unbound", binding: .none, modelID: nil, parentConversationID: nil
        )
        #expect(await fixture.store.fetchConversation(id: rootID)?.projectPath == nil)

        let bridge = SubagentConversationBridge(conversations: manager)
        let childID = try await bridge.createChildConversation(parentID: rootID, description: "child")

        let child = try #require(await fixture.store.fetchConversation(id: childID))
        #expect(child.projectPath == nil)
    }

    // MARK: - 消息隔离

    @Test("子会话消息不进入父会话历史，父会话消息不进入子会话历史")
    func childMessagesStayOutOfParentHistory() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let messages = DefaultMessageManager()
        let manager = ConversationManager(
            store: fixture.store, dataDirectory: fixture.directory, messageManager: messages
        )
        let rootID = try await manager.createConversationAndWait(
            title: "Root", projectPath: nil, modelID: nil, parentConversationID: nil
        )
        let bridge = SubagentConversationBridge(conversations: manager)
        let childID = try await bridge.createChildConversation(parentID: rootID, description: "child")

        messages.insertMessage(
            Message(conversationID: rootID, role: .user, content: "parent question"), to: rootID
        )
        messages.insertMessage(
            Message(conversationID: childID, role: .user, content: "child task"), to: childID
        )
        messages.insertMessage(
            Message(conversationID: childID, role: .assistant, content: "child answer"), to: childID
        )

        let parentHistory = await messages.messagesForLLM(in: rootID)
        #expect(parentHistory.map(\.content) == ["parent question"])
        let childHistory = await messages.messagesForLLM(in: childID)
        #expect(childHistory.map(\.content) == ["child task", "child answer"])
    }

    // MARK: - 删除级联

    @Test("删除父会话连带删除子会话库行并清空子会话消息")
    func deletingParentCascadesChildRowAndMessages() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let messages = DefaultMessageManager()
        let manager = ConversationManager(
            store: fixture.store, dataDirectory: fixture.directory, messageManager: messages
        )
        let rootID = try await manager.createConversationAndWait(
            title: "Root", projectPath: nil, modelID: nil, parentConversationID: nil
        )
        let bridge = SubagentConversationBridge(conversations: manager)
        let childID = try await bridge.createChildConversation(parentID: rootID, description: "child")
        messages.insertMessage(
            Message(conversationID: childID, role: .assistant, content: "child answer"), to: childID
        )

        manager.deleteConversation(id: rootID)

        try await waitUntil { await fixture.store.fetchConversation(id: childID) == nil }
        #expect(await fixture.store.fetchConversation(id: rootID) == nil)
        #expect(messages.messages(for: childID).isEmpty)
    }

    @Test("删除父会话连带取消子会话回合并删除其工具调用记录")
    func deletingParentCancelsChildTurnAndClearsToolCalls() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let agentLoop = AgentLoopSpy()
        let toolManager = ToolManagerSpy()
        let manager = ConversationManager(
            store: fixture.store,
            dataDirectory: fixture.directory,
            toolManager: toolManager,
            agentTurn: agentLoop
        )
        let rootID = try await manager.createConversationAndWait(
            title: "Root", projectPath: nil, modelID: nil, parentConversationID: nil
        )
        let bridge = SubagentConversationBridge(conversations: manager)
        let childID = try await bridge.createChildConversation(parentID: rootID, description: "child")

        manager.deleteConversation(id: rootID)

        try await waitUntil {
            agentLoop.cancelledConversationIDs.contains(childID)
                && toolManager.deletedConversationIDs.contains(childID)
        }
        #expect(agentLoop.cancelledConversationIDs.contains(rootID))
        #expect(toolManager.deletedConversationIDs.contains(rootID))
    }

    // MARK: - 错误

    @Test("父会话不存在时抛出 parentConversationNotFound")
    func missingParentThrows() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let bridge = SubagentConversationBridge(conversations: fixture.manager)
        let missingID = UUID()
        await #expect(throws: SubagentConversationError.parentConversationNotFound(missingID)) {
            _ = try await bridge.createChildConversation(parentID: missingID, description: "child")
        }
    }

    // MARK: - Helpers

    private struct Fixture {
        let directory: URL
        let store: ConversationStore
        let manager: ConversationManager

        func cleanup() {
            try? FileManager.default.removeItem(at: directory)
        }
    }

    private func makeFixture() throws -> Fixture {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SubagentChildConversationTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = try ConversationStore(databaseRootURL: directory)
        let manager = ConversationManager(store: store, dataDirectory: directory)
        return Fixture(directory: directory, store: store, manager: manager)
    }

    private struct TimeoutError: Error {}

    private func waitUntil(
        timeout: TimeInterval = 5,
        _ condition: @MainActor () async -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if await condition() { return }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        throw TimeoutError()
    }
}

// MARK: - Spies

@MainActor
private final class AgentLoopSpy: AgentLoopProviding {
    var cancelledConversationIDs: [UUID] = []

    func runTurn(in conversationID: UUID) async throws -> AgentLoopOutcome { .completed }
    func resumeTurn(in conversationID: UUID, request: AgentTurnResumeRequest) async throws -> AgentLoopOutcome { .completed }
    func cancelTurn(in conversationID: UUID) { cancelledConversationIDs.append(conversationID) }
    func state(for conversationID: UUID) -> AgentLoopState { .idle }
    func suspension(for conversationID: UUID) -> AgentLoopSuspension? { nil }
    func isRunning(for conversationID: UUID) -> Bool { false }
    func currentTurnID(for conversationID: UUID) -> UUID? { nil }
    func isAutoReplySuppressed(for conversationID: UUID) -> Bool { false }
    func setAutoReplySuppressed(_ suppressed: Bool, for conversationID: UUID) {}
    func setLifecycleHooks(_ hooks: (any LifecycleHooksProviding)?) {}
}

@MainActor
private final class ToolManagerSpy: ToolManagerProviding {
    var deletedConversationIDs: [UUID] = []

    func addToolManagerObserver(_ callback: @escaping (ToolManagerEvent) -> Void) -> any ToolManagerObserverHandle {
        NoopToolManagerObserverHandle()
    }
    func addToolJobObserver(_ callback: @escaping (ToolJobEvent) -> Void) -> any ToolJobObserverHandle {
        NoopToolJobObserverHandle()
    }
    func allTools() -> [any SuperAgentTool] { [] }
    func add(_ tool: any SuperAgentTool, pluginID: String) {}
    func remove(id: String) {}
    func toolsGroupedByPlugin() -> [(pluginID: String, tools: [any SuperAgentTool])] { [] }
    func tool(named name: String) -> (any SuperAgentTool)? { nil }
    func displayDescription(for toolCall: KitAgentTool.ToolCall) -> String? { nil }
    func riskLevel(for toolCall: KitAgentTool.ToolCall) -> CommandRiskLevel? { nil }
    func execute(_ toolCall: KitAgentTool.ToolCall, conversationID: UUID, turnID: UUID?) async -> ToolCallResult {
        ToolCallResult(content: "")
    }
    func toolCalls(for turnID: UUID) async -> [ToolCallRecord] { [] }
    func toolCallResult(for toolCallID: String) async -> ToolCallResult? { nil }
    func deleteToolCalls(for conversationID: UUID) async {
        deletedConversationIDs.append(conversationID)
    }
}

@MainActor
private final class ProjectSpy: ProjectProviding {
    var currentProject: ProjectInfo?
    var openFileURLs: [URL] = []
    var currentFileURL: URL?
    var projects: [ProjectInfo] = []

    func openProject(at path: String, reason: ProjectChangeReason) async throws {}
    func updateCurrentFile(_ fileURL: URL?) {}
    func previewFile(_ fileURL: URL) {}
    func pinFile(_ fileURL: URL) {}
    func activateFile(_ fileURL: URL) {}
    func updateOpenFiles(_ fileURLs: [URL]) {}
    func closeFile(_ fileURL: URL) {}
    func closeProject(reason: ProjectChangeReason) async {}
    func refreshProjects() async throws {}
    func synchronizeProjects(_ projects: [ProjectInfo]) {}
    func addObserver(_ callback: @escaping (ProjectProvidingEvent) -> Void) -> any ProjectProvidingObserverHandle {
        NoopProjectObserverHandle()
    }
}

private final class NoopToolManagerObserverHandle: ToolManagerObserverHandle {
    func cancel() {}
}

private final class NoopToolJobObserverHandle: ToolJobObserverHandle {
    func cancel() {}
}

private final class NoopProjectObserverHandle: ProjectProvidingObserverHandle {
    func cancel() {}
}