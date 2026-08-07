import Combine
import Foundation
import LumiKernel

// MARK: - Mock Message Manager

/// In-memory `MessageManaging` for integration tests.
/// Reads are `nonisolated` and lock-guarded (mirrors the real manager's
/// actor-split); writes are `@MainActor`.
final class MockMessageManager: MessageManaging, @unchecked Sendable {
    private let lock = NSLock()
    private var store: [UUID: [LumiChatMessage]] = [:]
    /// Messages inserted since the last manual reset, per conversation.
    private var insertedCount: [UUID: Int] = [:]

    func seed(_ messages: [LumiChatMessage], conversationID: UUID) {
        lock.lock()
        defer { lock.unlock() }
        store[conversationID, default: []].append(contentsOf: messages)
        store[conversationID] = store[conversationID]?.sorted(by: Self.timeOrder)
    }

    // MARK: - Read path (nonisolated)

    func messages(for conversationID: UUID) -> [LumiChatMessage] {
        lock.lock()
        defer { lock.unlock() }
        return (store[conversationID] ?? []).sorted(by: Self.timeOrder)
    }

    func messagePage(
        for conversationID: UUID,
        limit: Int,
        beforeMessageID: UUID?,
        includesToolMessages: Bool
    ) -> [LumiChatMessage] {
        lock.lock()
        defer { lock.unlock() }
        var all = (store[conversationID] ?? []).sorted(by: Self.timeOrder)
        if !includesToolMessages {
            all = all.filter { $0.role != .tool }
        }
        if let beforeMessageID,
           let index = all.firstIndex(where: { $0.id == beforeMessageID }) {
            all = Array(all[..<index])
        }
        return Array(all.suffix(limit))
    }

    func messageCount(for conversationID: UUID) -> Int {
        lock.lock()
        defer { lock.unlock() }
        return store[conversationID]?.count ?? 0
    }

    func conversationIDsHavingMessages() -> Set<UUID> {
        lock.lock()
        defer { lock.unlock() }
        return Set(store.keys)
    }

    func hasEarlierMessages(
        for conversationID: UUID,
        beforeMessageID: UUID?,
        includesToolMessages: Bool
    ) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        var all = (store[conversationID] ?? []).sorted(by: Self.timeOrder)
        if !includesToolMessages {
            all = all.filter { $0.role != .tool }
        }
        guard let beforeMessageID,
              let index = all.firstIndex(where: { $0.id == beforeMessageID }) else { return false }
        return index > 0
    }

    func message(id: UUID, in conversationID: UUID) -> LumiChatMessage? {
        lock.lock()
        defer { lock.unlock() }
        return (store[conversationID] ?? []).first { $0.id == id }
    }

    func lastMessage(in conversationID: UUID) -> LumiChatMessage? {
        lock.lock()
        defer { lock.unlock() }
        return (store[conversationID] ?? []).sorted(by: Self.timeOrder).last
    }

    // MARK: - Write path (@MainActor)

    @MainActor
    func insertMessage(_ message: LumiChatMessage, to conversationID: UUID) {
        lock.lock()
        var all = store[conversationID] ?? []
        all.append(message)
        store[conversationID] = all.sorted(by: Self.timeOrder)
        insertedCount[conversationID, default: 0] += 1
        lock.unlock()
    }

    @MainActor
    func deleteMessage(id: UUID, in conversationID: UUID) {
        lock.lock()
        store[conversationID] = (store[conversationID] ?? []).filter { $0.id != id }
        lock.unlock()
    }

    @MainActor
    func updateMessage(id: UUID, in conversationID: UUID, content: String) {
        lock.lock()
        defer { lock.unlock() }
        guard let index = (store[conversationID] ?? []).firstIndex(where: { $0.id == id }) else { return }
        store[conversationID]?[index].content = content
    }

    @MainActor
    func updateToolCallResult(
        _ result: LumiToolResult,
        toolCallID: String,
        assistantMessageID: UUID,
        in conversationID: UUID
    ) {
        lock.lock()
        defer { lock.unlock() }
        guard var all = store[conversationID],
              let index = all.firstIndex(where: { $0.id == assistantMessageID }) else { return }
        all[index].toolCalls = all[index].toolCalls?.map { call in
            call.id == toolCallID ? LumiToolCall(
                id: call.id, name: call.name, arguments: call.arguments,
                result: result, displayDescription: call.displayDescription
            ) : call
        }
        store[conversationID] = all
    }

    @MainActor
    func clearMessages(in conversationID: UUID) {
        lock.lock()
        store[conversationID] = []
        lock.unlock()
    }

    @MainActor
    func clearStatusMessage(in conversationID: UUID) {
        lock.lock()
        store[conversationID] = (store[conversationID] ?? []).filter { $0.role != .status }
        lock.unlock()
    }

    // MARK: - Async statistics (unused by the coordinator)

    func fetchDailyMessageCounts(since: Date) async -> [Date: Int] { [:] }
    func fetchDailyTokenCounts(since: Date) async -> [Date: Int] { [:] }
    func fetchTokenUsage(on day: Date, providerID: String?, modelName: String?) async -> MessageTokenUsage {
        MessageTokenUsage(day: day, inputTokens: 0, outputTokens: 0)
    }

    static func timeOrder(_ lhs: LumiChatMessage, _ rhs: LumiChatMessage) -> Bool {
        if lhs.createdAt == rhs.createdAt { return lhs.id.uuidString < rhs.id.uuidString }
        return lhs.createdAt < rhs.createdAt
    }
}

// MARK: - Mock Agent Turn Manager

@MainActor
final class MockAgentTurnManager: AgentTurnManaging {
    var recordsByConversation: [UUID: [AgentTurnRecord]] = [:]
    var runningConversations: Set<UUID> = []

    func seed(_ records: [AgentTurnRecord], conversationID: UUID) {
        recordsByConversation[conversationID] = records
    }

    func runTurn(in conversationID: UUID) async throws -> AgentTurnOutcome {
        .cancelled
    }

    func cancelTurn(in conversationID: UUID) {
        runningConversations.remove(conversationID)
    }

    func isRunning(for conversationID: UUID) -> Bool {
        runningConversations.contains(conversationID)
    }

    func turnRecords(
        for conversationID: UUID,
        limit: Int,
        before turnID: UUID?
    ) async -> [AgentTurnRecord] {
        var records = (recordsByConversation[conversationID] ?? []).sorted {
            if $0.startedAt == $1.startedAt { return $0.id.uuidString > $1.id.uuidString }
            return $0.startedAt > $1.startedAt
        }
        if let turnID, let index = records.firstIndex(where: { $0.id == turnID }) {
            records = Array(records[(index + 1)...])
        }
        return Array(records.prefix(limit))
    }
}

// MARK: - Mock Conversation Manager

@MainActor
final class MockConversationManager: ConversationManaging {
    var selectedConversationID: UUID?
    var conversations: [LumiConversationSummary] = []
    var globalVerbosity: LumiResponseVerbosity = .defaultVerbosity
    var currentTitle: String = ""
    var dataDirectory: URL = FileManager.default.temporaryDirectory

    func setGlobalVerbosity(_ verbosity: LumiResponseVerbosity) {
        globalVerbosity = verbosity
    }

    func verbosity(for conversationID: UUID?) -> LumiResponseVerbosity {
        globalVerbosity
    }

    func setVerbosity(_ verbosity: LumiResponseVerbosity, for conversationID: UUID?) {
        globalVerbosity = verbosity
    }

    func createConversation(
        title: String?, projectPath: String?, providerID: String?, modelName: String?
    ) throws -> UUID {
        let id = UUID()
        conversations.append(LumiConversationSummary(
            id: id, title: title ?? "", createdAt: Date(), updatedAt: Date(),
            providerID: providerID, modelName: modelName, projectPath: projectPath
        ))
        return id
    }

    func selectConversation(id: UUID) {
        selectedConversationID = id
    }

    func deleteConversation(id: UUID) {
        conversations.removeAll { $0.id == id }
        if selectedConversationID == id { selectedConversationID = nil }
    }

    func updateConversationTitle(_ title: String, for conversationID: UUID) -> Bool { true }

    func isSending(for conversationID: UUID?) -> Bool { false }

    func mockConversationIDs() -> [UUID] { conversations.map(\.id) }

    func providerID(for conversationID: UUID?) -> String? { nil }
    func modelName(for conversationID: UUID?) -> String? { nil }
    func selectProvider(id: String, model: String?, for conversationID: UUID?) {}

    func reasoningEffort(for conversationID: UUID?) -> LumiReasoningEffort { .high }
    func setReasoningEffort(_ reasoningEffort: LumiReasoningEffort, for conversationID: UUID?) {}

    func automationLevel(for conversationID: UUID?) -> LumiAutomationLevel { .chat }
    func setAutomationLevel(_ automationLevel: LumiAutomationLevel, for conversationID: UUID?) {}

    func language(for conversationID: UUID?) -> LumiConversationLanguage { .chinese }
    func setLanguage(_ language: LumiConversationLanguage, for conversationID: UUID?) {}
}

// MARK: - Mock Message Streaming

@MainActor
final class MockMessageStreaming: MessageStreaming {
    // @Published 自动合成 nonisolated objectWillChange（与真实 MessageStreamingStore 一致）。
    @Published private var rows: [UUID: LumiChatMessage] = [:]
    @Published private var stages: [UUID: ChatStage] = [:]

    func streamingRow(for conversationID: UUID) -> LumiChatMessage? {
        rows[conversationID]
    }

    func streamingStage(for conversationID: UUID) -> ChatStage {
        stages[conversationID] ?? .idle
    }

    func startStreaming(conversationID: UUID) async {
        rows[conversationID] = LumiChatMessage(
            id: LumiStreamingRowID,
            conversationID: conversationID,
            role: .assistant,
            content: ""
        )
        stages[conversationID] = .sending
    }

    func appendContent(_ piece: String, conversationID: UUID) async {
        guard let row = rows[conversationID] else { return }
        rows[conversationID] = LumiChatMessage(
            id: LumiStreamingRowID,
            conversationID: row.conversationID,
            role: .assistant,
            content: row.content + piece,
            providerID: row.providerID,
            modelName: row.modelName
        )
        stages[conversationID] = .generating
    }

    func appendThinking(_ piece: String, conversationID: UUID) async {
        guard let row = rows[conversationID] else { return }
        rows[conversationID] = LumiChatMessage(
            id: LumiStreamingRowID,
            conversationID: row.conversationID,
            role: .assistant,
            content: row.content,
            providerID: row.providerID,
            modelName: row.modelName,
            reasoningContent: (row.reasoningContent ?? "") + piece
        )
        stages[conversationID] = .thinking
    }

    func endStreaming(conversationID: UUID) async {
        rows[conversationID] = nil
        stages[conversationID] = .idle
    }

    /// Test helper: snap a streaming row for a stage without async writes.
    func inject(row: LumiChatMessage?, stage: ChatStage, conversationID: UUID) {
        rows[conversationID] = row
        stages[conversationID] = stage
    }
}
