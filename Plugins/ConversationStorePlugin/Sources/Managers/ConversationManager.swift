import Foundation
import LumiKernel
import LumiKernel
import SuperLogKit
import os

// MARK: - Notifications

public extension Notification.Name {
    static let conversationsDidChange = Notification.Name("com.coffic.lumi.conversationsDidChange")
}

/// Conversation Manager - real implementation using SwiftData persistence
///
/// Uses in-memory array for sync access, persists to SQLite async via ConversationStore.
@MainActor
public final class ConversationManager: ObservableObject, ConversationManaging, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.conversation-manager")
    nonisolated public static let emoji = "💬"
    public static let verbose = false

    @Published public private(set) var conversations: [LumiConversationSummary] = []
    @Published public private(set) var selectedConversationID: UUID?
    @Published public private(set) var currentTitle: String = "No conversation"

    /// Notification posted when conversations list changes
    static let conversationsDidChangeNotification = Notification.Name("com.coffic.lumi.conversationsDidChange")

    private weak var kernel: LumiKernel?

    public var dataDirectory: URL {
        ConversationManagerRuntimeBridge.shared.dataDirectory ?? ConversationStore.defaultDatabaseRootURL
    }

    // MARK: - Initialization

    public init(kernel: LumiKernel) {
        self.kernel = kernel
        if Self.verbose {
            Self.logger.info("\(Self.t)ConversationManager initialized")
        }
    }

    // MARK: - Store Access

    private var store: ConversationStore? {
        ConversationManagerRuntimeBridge.shared.store
    }

    // MARK: - Load

    /// Load conversations from store (called during boot)
    public func loadConversations() {
        guard let store else {
            if Self.verbose {
                Self.logger.warning("\(Self.t)Store not available, using empty list")
            }
            conversations = []
            return
        }

        // Synchronous load on MainActor - the store.fetchConversations is async but we await it
        Task {
            let loaded = await store.fetchConversations()
            await MainActor.run {
                self.conversations = loaded
                // Restore selected conversation if it still exists
                if let selectedID = self.selectedConversationID,
                   !loaded.contains(where: { $0.id == selectedID }) {
                    self.selectedConversationID = loaded.first?.id
                }
                self.updateCurrentTitle()
                self.notifyConversationsChanged()

                if Self.verbose {
                    Self.logger.info("\(Self.t)Loaded \(loaded.count) conversations")
                }
            }
        }
    }

    /// Notify observers that conversations changed
    private func notifyConversationsChanged() {
        NotificationCenter.default.post(name: Self.conversationsDidChangeNotification, object: self)
    }

    // MARK: - ConversationManaging

    public func createConversation(title: String?) throws -> UUID {
        let now = Date()
        let id = UUID()
        let conversationTitle = title ?? "New Chat"

        if Self.verbose {
            Self.logger.info("\(Self.t)Creating conversation: \(conversationTitle)")
        }

        let conversation = LumiConversationSummary(
            id: id,
            title: conversationTitle,
            preview: "",
            createdAt: now,
            updatedAt: now
        )

        // Add to in-memory list immediately
        conversations.insert(conversation, at: 0)
        selectedConversationID = id
        updateCurrentTitle()
        notifyConversationsChanged()

        // Persist to database async
        Task {
            do {
                try await store?.createConversation(id: id, title: conversationTitle, preview: "", createdAt: now)
            } catch {
                if Self.verbose {
                    Self.logger.error("\(Self.t)Failed to persist conversation: \(error)")
                }
            }
        }

        if Self.verbose {
            Self.logger.info("\(Self.t)Created conversation \(id.uuidString.prefix(8))...")
        }

        return id
    }

    public func selectConversation(id: UUID) {
        if Self.verbose {
            Self.logger.info("\(Self.t)Selecting conversation \(id.uuidString.prefix(8))...")
        }
        selectedConversationID = id
        updateCurrentTitle()

        // Touch the conversation to update its timestamp (async)
        Task {
            await store?.touchConversation(id: id)
        }
    }

    public func deleteConversation(id: UUID) {
        if Self.verbose {
            Self.logger.info("\(Self.t)Deleting conversation \(id.uuidString.prefix(8))...")
        }

        conversations.removeAll { $0.id == id }

        if selectedConversationID == id {
            selectedConversationID = conversations.first?.id
            updateCurrentTitle()
        }

        notifyConversationsChanged()

        // Delete from database async
        Task {
            await store?.deleteConversation(id: id)
        }
    }

    public func isSending(for conversationID: UUID?) -> Bool {
        // TODO: Implement based on actual sending state
        return false
    }

    public func mockConversationIDs() -> [UUID] {
        // Return actual conversation IDs for message data association
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

        // Persist to database async
        Task {
            await store?.updateConversationProvider(id: conversationID, providerID: id, modelName: model)
        }

        if Self.verbose {
            Self.logger.info("\(Self.t)selectProvider: conversation=\(conversationID.uuidString.prefix(8)), provider=\(id), model=\(model ?? "nil")")
        }
    }

    // MARK: - Private

    private func updateCurrentTitle() {
        guard let selectedID = selectedConversationID,
              let conversation = conversations.first(where: { $0.id == selectedID })
        else {
            currentTitle = "No conversation"
            return
        }
        let newTitle = conversation.title.isEmpty ? "Untitled" : conversation.title
        currentTitle = newTitle
    }
}

// MARK: - Runtime Bridge

@MainActor
final class ConversationManagerRuntimeBridge: @unchecked Sendable {
    static let shared = ConversationManagerRuntimeBridge()

    var store: ConversationStore?
    var dataDirectory: URL?

    private init() {}
}
