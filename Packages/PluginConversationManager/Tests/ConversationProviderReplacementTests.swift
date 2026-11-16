import Foundation
import ProviderAgentLoop
import ProviderConversation
import ProviderLifecycleHooks
import ProviderMessage
import Testing
@testable import PluginConversationManager

/// 回归 #640：ConversationManager 在 order 7 创建时捕获的默认 Message/AgentLoop
/// 会被 order 8 插件替换。删除（单条/批量）与设置页统计必须动态解析当前生产
/// Provider，否则取消回合/清消息落在无人使用的默认实例上，生产回合继续跑、
/// 生产消息不被清理，统计读取空默认管理器。
@MainActor
@Suite(.serialized)
struct ConversationProviderReplacementTests {
    /// 单条删除：替换后 cancelTurn/clearMessages 必须落在生产实例，而非默认实例。
    @Test func singleDeletionCancelsAndClearsCurrentProductionProviders() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ConversationProviderReplaceSingle-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let defaultMessage = ReplacementMessageManager()
        let defaultAgent = ReplacementAgentLoop()
        let productionMessage = ReplacementMessageManager()
        let productionAgent = ReplacementAgentLoop()
        let box = ProviderBox()
        box.message = defaultMessage
        box.agent = defaultAgent

        let manager = ConversationManager(
            store: nil,
            dataDirectory: directory,
            messageManager: defaultMessage,
            agentTurn: defaultAgent,
            messageManagerResolver: { box.message },
            agentTurnResolver: { box.agent }
        )
        let id = UUID()
        manager.conversations = [ConversationSummary(id: id, title: "Doomed")]

        // 模拟 order 8 插件把默认 Provider 替换为生产实现。
        box.message = productionMessage
        box.agent = productionAgent

        manager.deleteConversation(id: id)
        for _ in 0..<200 where productionAgent.cancelled.isEmpty {
            try await Task.sleep(for: .milliseconds(10))
        }

        #expect(productionAgent.cancelled == [id])
        #expect(productionMessage.cleared == [id])
        #expect(defaultAgent.cancelled.isEmpty, "不得把取消回合发给已被替换的默认 AgentLoop")
        #expect(defaultMessage.cleared.isEmpty, "不得把清消息发给已被替换的默认 MessageManager")
    }

    /// 批量清理：同样必须作用于替换后的生产 Provider。
    @Test func batchDeletionCancelsAndClearsCurrentProductionProviders() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ConversationProviderReplaceBatch-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = try ConversationStore(databaseRootURL: directory)
        let now = Date()
        let old = UUID()
        try await store.createConversation(
            id: old, title: "old", createdAt: now.addingTimeInterval(-86_400 * 10)
        )

        let defaultMessage = ReplacementMessageManager()
        let defaultAgent = ReplacementAgentLoop()
        let productionMessage = ReplacementMessageManager()
        let productionAgent = ReplacementAgentLoop()
        let box = ProviderBox()
        box.message = defaultMessage
        box.agent = defaultAgent

        let manager = ConversationManager(
            store: store,
            dataDirectory: directory,
            messageManager: defaultMessage,
            agentTurn: defaultAgent,
            messageManagerResolver: { box.message },
            agentTurnResolver: { box.agent }
        )
        box.message = productionMessage
        box.agent = productionAgent

        let deleted = await manager.deleteConversations(
            createdBefore: now.addingTimeInterval(-86_400),
            projectPath: nil,
            includingChildConversations: false
        )

        #expect(deleted == [old])
        #expect(productionAgent.cancelled == [old])
        #expect(productionMessage.cleared == [old])
        #expect(defaultAgent.cancelled.isEmpty)
        #expect(defaultMessage.cleared.isEmpty)
    }

    /// 设置页统计：Capability 的 count/snapshot 必须读取替换后的生产 MessageManager。
    @Test func capabilityStatisticsReadCurrentProductionMessageManager() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ConversationProviderReplaceStats-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let defaultMessage = ReplacementMessageManager()
        defaultMessage.count = 0
        let productionMessage = ReplacementMessageManager()
        productionMessage.count = 7
        let id = UUID()
        productionMessage.snapshot = [Message(conversationID: id, role: .assistant, content: "production")]
        let box = ProviderBox()
        box.message = defaultMessage

        let manager = ConversationManager(
            store: nil,
            dataDirectory: directory,
            messageManager: defaultMessage,
            messageManagerResolver: { box.message }
        )
        let capability = ConversationStoreCapabilityAdapter(manager: manager)

        // 替换前读取默认（空）管理器。
        #expect(capability.messageCount(for: id) == 0)
        box.message = productionMessage
        #expect(capability.messageCount(for: id) == 7, "统计须读取生产 MessageManager 的计数")
        let snapshot = await capability.messagesSnapshot(in: id)
        #expect(snapshot.count == 1)
        #expect(snapshot.first?.content == "production")
    }

    /// 无解析器时回退到创建时捕获的 Provider（直接注入/旧调用方不被破坏）。
    @Test func managerFallsBackToCapturedProvidersWithoutResolver() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ConversationProviderReplaceFallback-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let capturedMessage = ReplacementMessageManager()
        let capturedAgent = ReplacementAgentLoop()
        let manager = ConversationManager(
            store: nil,
            dataDirectory: directory,
            messageManager: capturedMessage,
            agentTurn: capturedAgent
        )
        let id = UUID()
        manager.conversations = [ConversationSummary(id: id, title: "Doomed")]

        manager.deleteConversation(id: id)
        for _ in 0..<200 where capturedAgent.cancelled.isEmpty {
            try await Task.sleep(for: .milliseconds(10))
        }

        #expect(capturedAgent.cancelled == [id])
        #expect(capturedMessage.cleared == [id])
    }
}

/// 模拟内核 Provider 注册表：解析器每次读取这里的当前值，
/// 测试通过改写它来模拟 order 8 插件替换默认 Provider。
@MainActor
private final class ProviderBox {
    var message: (any MessageManaging)?
    var agent: (any AgentLoopProviding)?
}

/// 记录 clearMessages 调用、并提供可控 count/snapshot 的消息管理器替身。
@MainActor
private final class ReplacementMessageManager: MessageManaging {
    var cleared: [UUID] = []
    var count: Int = 0
    var snapshot: [Message] = []

    func messages(for conversationID: UUID) -> [Message] { snapshot }
    func messagesSnapshot(in conversationID: UUID) async -> [Message] { snapshot }
    func message(id: UUID, in conversationID: UUID) -> Message? { nil }
    func lastMessage(in conversationID: UUID) -> Message? { nil }
    func messageCount(for conversationID: UUID) -> Int { count }
    func insertMessage(_ message: Message, to conversationID: UUID) {}
    func updateMessage(id: UUID, in conversationID: UUID, content: String) {}
    func deleteMessage(id: UUID, in conversationID: UUID) {}
    func clearMessages(in conversationID: UUID) { cleared.append(conversationID) }
    func updateToolCallResult(
        _ result: MessageToolResult,
        toolCallID: String,
        assistantMessageID: UUID,
        in conversationID: UUID,
        authorizationState: String?
    ) {}
}

/// 记录 cancelTurn 调用的 Agent 回合替身；其余方法返回平凡值。
@MainActor
private final class ReplacementAgentLoop: AgentLoopProviding {
    var cancelled: [UUID] = []

    func runTurn(in conversationID: UUID) async throws -> AgentLoopOutcome { .completed }
    func resumeTurn(in conversationID: UUID, request: AgentTurnResumeRequest) async throws -> AgentLoopOutcome { .completed }
    func cancelTurn(in conversationID: UUID) { cancelled.append(conversationID) }
    func state(for conversationID: UUID) -> AgentLoopState { .idle }
    func suspension(for conversationID: UUID) -> AgentLoopSuspension? { nil }
    func isRunning(for conversationID: UUID) -> Bool { false }
    func currentTurnID(for conversationID: UUID) -> UUID? { nil }
    func setLifecycleHooks(_ hooks: (any LifecycleHooksProviding)?) {}
}