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
    @Published public private(set) var currentTitle: String = "No conversation"

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

    public func createConversation(title: String?, projectPath: String?, providerID: String?, modelName: String?) throws -> UUID {
        let now = Date()
        let id = UUID()
        let normalizedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let storedTitle = normalizedTitle?.isEmpty == true ? nil : normalizedTitle

        let conversation = LumiConversationSummary(
            id: id,
            title: storedTitle,
            preview: "",
            createdAt: now,
            updatedAt: now,
            providerID: providerID,
            modelName: modelName,
            projectPath: projectPath
        )

        conversations.insert(conversation, at: 0)

        do {
            try saveConversations()
        } catch {
            conversations.removeAll { $0.id == id }
            throw error
        }

        selectConversation(id: id)
        updateCurrentTitle()
        return id
    }

    public func selectConversation(id: UUID) {
        selectedConversationID = id
        updateCurrentTitle()
        try? saveState()
    }

    private func updateCurrentTitle() {
        guard let selectedID = selectedConversationID,
              let conversation = conversations.first(where: { $0.id == selectedID })
        else {
            currentTitle = "No conversation"
            return
        }
        currentTitle = conversation.displayTitle
    }

    public func deleteConversation(id: UUID) {
        conversations.removeAll { $0.id == id }

        if selectedConversationID == id {
            selectedConversationID = conversations.first?.id
        }

        try? saveConversations()
        try? saveState()
    }

    public func updateConversationTitle(_ title: String, for conversationID: UUID) -> Bool {
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else {
            return false
        }
        let normalized = title.trimmingCharacters(in: .whitespacesAndNewlines)
        conversations[index].title = normalized.isEmpty ? nil : normalized
        if conversationID == selectedConversationID {
            updateCurrentTitle()
        }
        try? saveConversations()
        return true
    }

    public func isSending(for conversationID: UUID?) -> Bool {
        // TODO: Implement based on actual sending state
        return false
    }

    public func mockConversationIDs() -> [UUID] {
        // Return actual conversation IDs for mock message data association
        conversations.map(\.id)
    }

    // MARK: - Provider/Model Selection

    public func providerID(for conversationID: UUID?) -> String? {
        guard let conversationID else {
            return nil
        }
        return conversations.first { $0.id == conversationID }?.providerID
    }

    public func modelName(for conversationID: UUID?) -> String? {
        guard let conversationID else {
            return nil
        }
        return conversations.first { $0.id == conversationID }?.modelName
    }

    public func selectProvider(id: String, model: String?, for conversationID: UUID?) {
        guard let conversationID else {
            return
        }
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else {
            return
        }
        conversations[index].providerID = id
        conversations[index].modelName = model
        try? saveConversations()
    }

    // MARK: - Verbosity

    public func verbosity(for conversationID: UUID?) -> LumiResponseVerbosity {
        guard let conversationID else {
            return .defaultVerbosity
        }
        return conversations.first { $0.id == conversationID }?.verbosity ?? .defaultVerbosity
    }

    public func setVerbosity(_ verbosity: LumiResponseVerbosity, for conversationID: UUID?) {
        guard let conversationID else {
            return
        }
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else {
            return
        }
        conversations[index].verbosity = verbosity
        try? saveConversations()
    }

    // MARK: - Automation Level

    public func automationLevel(for conversationID: UUID?) -> LumiAutomationLevel {
        guard let conversationID else {
            return .build
        }
        return conversations.first { $0.id == conversationID }?.automationLevel ?? .build
    }

    public func setAutomationLevel(_ automationLevel: LumiAutomationLevel, for conversationID: UUID?) {
        guard let conversationID else {
            return
        }
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else {
            return
        }
        conversations[index].automationLevel = automationLevel
        try? saveConversations()
    }

    public func language(for conversationID: UUID?) -> LumiConversationLanguage {
        guard let conversationID else {
            return .chinese
        }
        return conversations.first { $0.id == conversationID }?.language ?? .chinese
    }

    public func setLanguage(_ language: LumiConversationLanguage, for conversationID: UUID?) {
        guard let conversationID else {
            return
        }
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else {
            return
        }
        conversations[index].language = language
        try? saveConversations()
    }
}

// MARK: - State

private struct ConversationState: Codable {
    let selectedConversationID: UUID?
}
