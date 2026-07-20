import Foundation
import LumiKernel
import os

/// Conversation service implementation using JSON file storage
@MainActor
public final class ConversationService: ConversationManaging {
    private let storageDirectory: URL
    private let conversationsFileURL: URL
    private let stateFileURL: URL

    @Published public private(set) var conversations: [LumiConversationSummary] = []
    @Published public private(set) var selectedConversationID: UUID?

    public var dataDirectory: URL { storageDirectory }

    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.conversation-manager.service")

    // MARK: - Init

    public init(storageDirectory: URL) throws {
        self.storageDirectory = storageDirectory

        // Ensure directory exists
        try FileManager.default.createDirectory(
            at: storageDirectory,
            withIntermediateDirectories: true
        )

        self.conversationsFileURL = storageDirectory.appendingPathComponent("conversations.json")
        self.stateFileURL = storageDirectory.appendingPathComponent("state.json")

        loadConversations()
        loadState()
    }

    // MARK: - Load/Save

    private func loadConversations() {
        guard FileManager.default.fileExists(atPath: conversationsFileURL.path) else {
            conversations = []
            return
        }

        do {
            let data = try Data(contentsOf: conversationsFileURL)
            conversations = try JSONDecoder().decode([LumiConversationSummary].self, from: data)
        } catch {
            Self.logger.error("加载对话列表失败: \(error)")
            conversations = []
        }
    }

    private func loadState() {
        guard FileManager.default.fileExists(atPath: stateFileURL.path) else {
            return
        }

        do {
            let data = try Data(contentsOf: stateFileURL)
            let state = try JSONDecoder().decode(ConversationState.self, from: data)
            selectedConversationID = state.selectedConversationID
        } catch {
            Self.logger.error("加载对话状态失败: \(error)")
        }
    }

    private func saveConversations() throws {
        let data = try JSONEncoder().encode(conversations)
        try data.write(to: conversationsFileURL, options: .atomic)
    }

    private func saveState() throws {
        let state = ConversationState(selectedConversationID: selectedConversationID)
        let data = try JSONEncoder().encode(state)
        try data.write(to: stateFileURL, options: .atomic)
    }

    // MARK: - ConversationManaging

    public func createConversation(title: String?) throws -> UUID {
        let now = Date()
        let id = UUID()

        let conversation = LumiConversationSummary(
            id: id,
            title: title ?? "",
            preview: "",
            createdAt: now,
            updatedAt: now
        )

        conversations.insert(conversation, at: 0)

        do {
            try saveConversations()
        } catch {
            conversations.removeAll { $0.id == id }
            throw error
        }

        selectConversation(id: id)
        return id
    }

    public func selectConversation(id: UUID) {
        selectedConversationID = id
        try? saveState()
    }

    public func deleteConversation(id: UUID) {
        conversations.removeAll { $0.id == id }

        if selectedConversationID == id {
            selectedConversationID = conversations.first?.id
        }

        try? saveConversations()
        try? saveState()
    }

    public func isSending(for conversationID: UUID?) -> Bool {
        // TODO: Implement based on actual sending state
        return false
    }
}

// MARK: - State

private struct ConversationState: Codable {
    let selectedConversationID: UUID?
}
