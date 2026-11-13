import Foundation
import KitAgentTool
import ProviderAgentLoop
import ProviderConversation
import ProviderLifecycleHooks
import ProviderMessage
import ProviderToolManager
import Testing
@testable import PluginConversationManager
@testable import PluginSubagent

/// #1328 Task 2：从持久化数据派生子代理树。
///
/// 注册表不引入第二份真源：名字来自根会话里的委托卡片载荷，状态来自
/// ToolJob，活跃状态来自 AgentLoop。树根通过 `parentConversationID`
/// 逐级上溯得到；根会话本身寻址为 `lead`。
@MainActor
@Suite(.serialized)
struct SubagentRegistryTests {

    @Test("从根会话的委托卡片重建成员与 Job 关联")
    func rebuildsMembersFromPersistedCards() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let rootID = try await fixture.makeRoot()
        let explorer = try await fixture.makeChild(of: rootID, label: "Explorer", name: "explorer", jobID: "job-explorer", createdAt: .init(timeIntervalSince1970: 100))
        let editor = try await fixture.makeChild(of: rootID, label: "Editor", name: "editor", jobID: "job-editor", createdAt: .init(timeIntervalSince1970: 200))

        let snapshot = try #require(await fixture.registry.snapshot(for: rootID))

        #expect(snapshot.rootConversationID == rootID)
        #expect(snapshot.members.map(\.name) == ["explorer", "editor"])
        #expect(snapshot.members.map(\.childConversationID) == [explorer, editor])
        #expect(snapshot.members.map(\.parentJobID) == ["job-explorer", "job-editor"])
        #expect(snapshot.members.map(\.isRunning) == [false, false])
    }

    @Test("子会话视角能解析 lead 与兄弟代理")
    func resolvesLeadAndSiblingsFromChild() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let rootID = try await fixture.makeRoot()
        let explorer = try await fixture.makeChild(of: rootID, label: "Explorer", name: "explorer", jobID: "job-explorer")
        let editor = try await fixture.makeChild(of: rootID, label: "Editor", name: "editor", jobID: "job-editor")

        let lead = try await fixture.registry.resolve(name: "lead", from: explorer)
        #expect(lead == .lead(conversationID: rootID))

        let sibling = try await fixture.registry.resolve(name: "editor", from: explorer)
        #expect(sibling == .child(name: "editor", conversationID: editor, parentJobID: "job-editor"))
    }

    @Test("新建注册表实例仍能从同一份持久化数据重建，不依赖内存缓存")
    func rebuildsInFreshRegistryInstance() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let rootID = try await fixture.makeRoot()
        _ = try await fixture.makeChild(of: rootID, label: "Explorer", name: "explorer", jobID: "job-explorer")

        let rebuilt = SubagentRegistry(
            conversations: fixture.manager,
            messages: fixture.messages,
            toolManager: fixture.toolManager,
            agentLoop: fixture.agentLoop
        )
        let snapshot = try #require(await rebuilt.snapshot(for: rootID))
        #expect(snapshot.members.map(\.name) == ["explorer"])
    }

    @Test("未知名字与另一棵树的成员都被拒绝")
    func rejectsUnknownAndForeignNames() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let rootID = try await fixture.makeRoot()
        _ = try await fixture.makeChild(of: rootID, label: "Explorer", name: "explorer", jobID: "job-explorer")

        let otherRoot = try await fixture.makeRoot()
        _ = try await fixture.makeChild(of: otherRoot, label: "Outsider", name: "outsider", jobID: "job-outsider")

        await #expect(throws: SubagentRegistryError.unknownName("missing")) {
            _ = try await fixture.registry.resolve(name: "missing", from: rootID)
        }
        await #expect(throws: SubagentRegistryError.unknownName("outsider")) {
            _ = try await fixture.registry.resolve(name: "outsider", from: rootID)
        }
    }

    @Test("已删除的子会话不参与寻址")
    func deletedChildIsNotAddressable() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let rootID = try await fixture.makeRoot()
        let explorer = try await fixture.makeChild(of: rootID, label: "Explorer", name: "explorer", jobID: "job-explorer")

        fixture.manager.deleteConversation(id: explorer)
        try await waitUntil { await fixture.manager.fetchConversation(id: explorer) == nil }

        let snapshot = try #require(await fixture.registry.snapshot(for: rootID))
        #expect(snapshot.members.isEmpty)
        await #expect(throws: SubagentRegistryError.unknownName("explorer")) {
            _ = try await fixture.registry.resolve(name: "explorer", from: rootID)
        }
    }

    @Test("没有名字的历史卡片保留展示但不可寻址")
    func legacyCardsStayVisibleButAreNotAddressable() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let rootID = try await fixture.makeRoot()
        _ = try await fixture.makeChild(of: rootID, label: "Legacy", name: nil, jobID: "job-legacy")

        let snapshot = try #require(await fixture.registry.snapshot(for: rootID))
        #expect(snapshot.members.count == 1)
        #expect(snapshot.members[0].name == nil)
        #expect(snapshot.members[0].isAddressable == false)
    }

    @Test("同一棵树内出现重名数据时拒绝猜测目标")
    func duplicateNamesAreAmbiguous() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let rootID = try await fixture.makeRoot()
        _ = try await fixture.makeChild(of: rootID, label: "A", name: "twin", jobID: "job-a")
        _ = try await fixture.makeChild(of: rootID, label: "B", name: "twin", jobID: "job-b")

        await #expect(throws: SubagentRegistryError.ambiguousName("twin")) {
            _ = try await fixture.registry.resolve(name: "twin", from: rootID)
        }
    }

    @Test("运行状态合并 Job 状态与 AgentLoop 活跃状态")
    func mergesJobAndAgentLoopState() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let rootID = try await fixture.makeRoot()
        let child = try await fixture.makeChild(of: rootID, label: "Explorer", name: "explorer", jobID: "job-explorer", status: .running)
        fixture.agentLoop.runningConversationIDs.insert(child)

        let snapshot = try #require(await fixture.registry.snapshot(for: rootID))
        #expect(snapshot.members[0].jobStatus == .running)
        #expect(snapshot.members[0].isRunning)
        #expect(snapshot.members[0].isResumable == false)

        fixture.toolManager.jobsByID["job-explorer"]?.status = .completed
        fixture.agentLoop.runningConversationIDs.remove(child)

        let finished = try #require(await fixture.registry.snapshot(for: rootID))
        #expect(finished.members[0].isRunning == false)
        #expect(finished.members[0].isResumable)
    }

    // MARK: - Fixture

    private struct Fixture {
        let directory: URL
        let manager: ConversationManager
        let messages: DefaultMessageManager
        let toolManager: RegistryToolManagerSpy
        let agentLoop: RegistryAgentLoopSpy
        let registry: SubagentRegistry

        func cleanup() {
            try? FileManager.default.removeItem(at: directory)
        }

        @MainActor
        func makeRoot() async throws -> UUID {
            try await manager.createConversationAndWait(
                title: "Root", projectPath: nil, modelID: nil, parentConversationID: nil
            )
        }

        @MainActor
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

    private func makeFixture() throws -> Fixture {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SubagentRegistryTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = try ConversationStore(databaseRootURL: directory)
        let messages = DefaultMessageManager()
        let toolManager = RegistryToolManagerSpy()
        let agentLoop = RegistryAgentLoopSpy()
        let manager = ConversationManager(
            store: store,
            dataDirectory: directory,
            messageManager: messages,
            toolManager: toolManager,
            agentTurn: agentLoop
        )
        let registry = SubagentRegistry(
            conversations: manager,
            messages: messages,
            toolManager: toolManager,
            agentLoop: agentLoop
        )
        return Fixture(
            directory: directory,
            manager: manager,
            messages: messages,
            toolManager: toolManager,
            agentLoop: agentLoop,
            registry: registry
        )
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
private final class RegistryAgentLoopSpy: AgentLoopProviding {
    var runningConversationIDs: Set<UUID> = []

    func runTurn(in conversationID: UUID) async throws -> AgentLoopOutcome { .completed }
    func resumeTurn(in conversationID: UUID, request: AgentTurnResumeRequest) async throws -> AgentLoopOutcome { .completed }
    func cancelTurn(in conversationID: UUID) { runningConversationIDs.remove(conversationID) }
    func state(for conversationID: UUID) -> AgentLoopState {
        runningConversationIDs.contains(conversationID) ? .running : .idle
    }
    func suspension(for conversationID: UUID) -> AgentLoopSuspension? { nil }
    func isRunning(for conversationID: UUID) -> Bool { runningConversationIDs.contains(conversationID) }
    func currentTurnID(for conversationID: UUID) -> UUID? { nil }
    func isAutoReplySuppressed(for conversationID: UUID) -> Bool { false }
    func setAutoReplySuppressed(_ suppressed: Bool, for conversationID: UUID) {}
    func setLifecycleHooks(_ hooks: (any LifecycleHooksProviding)?) {}
}

@MainActor
private final class RegistryToolManagerSpy: ToolManagerProviding {
    var jobsByID: [String: ToolJob] = [:]

    func jobs(forConversationID conversationID: UUID) -> [ToolJob] {
        jobsByID.values
            .filter { $0.conversationID == conversationID }
            .sorted { $0.createdAt < $1.createdAt }
    }

    func job(for jobID: String) -> ToolJob? {
        jobsByID[jobID]
    }

    func addToolManagerObserver(_ callback: @escaping (ToolManagerEvent) -> Void) -> any ToolManagerObserverHandle {
        RegistryObserverHandle()
    }
    func addToolJobObserver(_ callback: @escaping (ToolJobEvent) -> Void) -> any ToolJobObserverHandle {
        RegistryObserverHandle()
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

private final class RegistryObserverHandle: ToolManagerObserverHandle, ToolJobObserverHandle {
    func cancel() {}
}
