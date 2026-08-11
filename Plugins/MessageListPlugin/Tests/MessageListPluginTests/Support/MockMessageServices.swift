import Combine
import Foundation
import LumiKernel

// MARK: - Mock Message Manager

/// In-memory `MessageManaging` for message-list tests.
/// Mirrors the AppKit plugin's mock: reads are lock-guarded so the
/// pagination service can call them from `Task.detached`, writes are plain.
final class MockMessageManager: MessageManaging, @unchecked Sendable {
    private let lock = NSLock()
    private var store: [UUID: [LumiChatMessage]] = [:]

    /// 人为给 messagePage 读取加延迟,模拟慢盘/长对话下的异步 DB 读,
    /// 用于复现「切会话后 loadFirstPage 迟迟不返回」的竞态窗口。
    var readDelayNs: UInt64 = 0

    func seed(_ messages: [LumiChatMessage], conversationID: UUID) {
        lock.lock()
        defer { lock.unlock() }
        store[conversationID, default: []].append(contentsOf: messages)
        store[conversationID] = store[conversationID]?.sorted(by: Self.timeOrder)
    }

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
        if readDelayNs > 0 {
            Thread.sleep(forTimeInterval: Double(readDelayNs) / 1_000_000_000)
        }
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
              let index = all.firstIndex(where: { $0.id == beforeMessageID }) else {
            return false
        }
        return index > 0
    }

    func message(id: UUID, in conversationID: UUID) -> LumiChatMessage? {
        lock.lock()
        defer { lock.unlock() }
        return store[conversationID]?.first { $0.id == id }
    }

    func lastMessage(in conversationID: UUID) -> LumiChatMessage? {
        lock.lock()
        defer { lock.unlock() }
        return store[conversationID]?.sorted(by: Self.timeOrder).last
    }

    @MainActor
    func deleteMessage(id: UUID, in conversationID: UUID) {
        lock.lock()
        defer { lock.unlock() }
        store[conversationID]?.removeAll { $0.id == id }
    }

    @MainActor
    func insertMessage(_ message: LumiChatMessage, to conversationID: UUID) {
        lock.lock()
        defer { lock.unlock() }
        store[conversationID, default: []].append(message)
        store[conversationID] = store[conversationID]?.sorted(by: Self.timeOrder)
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

// MARK: - Mock Conversation Manager

@MainActor
final class MockConversationManager: ConversationManaging {
    var selectedConversationID: UUID?
    var conversations: [LumiConversationSummary] = []
    var globalVerbosity: LumiResponseVerbosity = .defaultVerbosity
    var currentTitle: String = ""
    var dataDirectory: URL = FileManager.default.temporaryDirectory

    func setGlobalVerbosity(_ verbosity: LumiResponseVerbosity) { globalVerbosity = verbosity }
    func verbosity(for conversationID: UUID?) -> LumiResponseVerbosity { globalVerbosity }
    func setVerbosity(_ verbosity: LumiResponseVerbosity, for conversationID: UUID?) { globalVerbosity = verbosity }

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

    func selectConversation(id: UUID) { selectedConversationID = id }
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
    func reasoningEffortOptional(for conversationID: UUID?) -> LumiReasoningEffort? { nil }
    func setReasoningEffort(_ reasoningEffort: LumiReasoningEffort, for conversationID: UUID?) {}
    func clearReasoningEffort(for conversationID: UUID?) {}
    func automationLevel(for conversationID: UUID?) -> LumiAutomationLevel { .chat }
    func setAutomationLevel(_ automationLevel: LumiAutomationLevel, for conversationID: UUID?) {}
    func language(for conversationID: UUID?) -> LumiConversationLanguage { .chinese }
    func setLanguage(_ language: LumiConversationLanguage, for conversationID: UUID?) {}
}

// MARK: - Mock Message Streaming

@MainActor
final class MockMessageStreaming: MessageStreaming {
    @Published private var rows: [UUID: LumiChatMessage] = [:]
    @Published private var stages: [UUID: ChatStage] = [:]

    func streamingRow(for conversationID: UUID) -> LumiChatMessage? { rows[conversationID] }
    func streamingStage(for conversationID: UUID) -> ChatStage { stages[conversationID] ?? .idle }

    func startStreaming(conversationID: UUID) async {}
    func appendContent(_ piece: String, conversationID: UUID) async {}
    func appendThinking(_ piece: String, conversationID: UUID) async {}
    func endStreaming(conversationID: UUID) async {}

    func inject(row: LumiChatMessage?, stage: ChatStage, conversationID: UUID) {
        rows[conversationID] = row
        stages[conversationID] = stage
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

    func runTurn(in conversationID: UUID) async throws -> AgentTurnOutcome { .cancelled }
    func cancelTurn(in conversationID: UUID) { runningConversations.remove(conversationID) }
    func isRunning(for conversationID: UUID) -> Bool { runningConversations.contains(conversationID) }

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

// MARK: - Test fixture helpers

extension MockMessageManager {
    /// 生成 n 条按时间升序的消息,交替 user/assistant,内容足够渲染。
    static func makeMessages(
        count: Int,
        conversationID: UUID,
        baseTime: TimeInterval = 1_000
    ) -> [LumiChatMessage] {
        (0..<count).map { i in
            LumiChatMessage(
                id: UUID(),
                conversationID: conversationID,
                role: i % 2 == 0 ? .user : .assistant,
                content: "message \(i) — some content to render in the list",
                createdAt: Date(timeIntervalSinceReferenceDate: baseTime + Double(i))
            )
        }
    }
}
