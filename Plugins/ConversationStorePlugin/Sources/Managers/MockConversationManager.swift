import Foundation
import LumiKernel
import SuperLogKit
import os

/// Mock conversation manager with sample data for testing
@MainActor
public final class MockConversationManager: ObservableObject, ConversationManaging, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.conversation-manager.mock")
    nonisolated public static let emoji = "💬"
    public static let verbose = true

    @Published public private(set) var conversations: [LumiConversationSummary] = []
    @Published public private(set) var selectedConversationID: UUID?
    @Published public private(set) var currentTitle: String = "No conversation"

    public var dataDirectory: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("MockConversations")
    }

    // Fixed mock IDs for testing - MessageManager uses these same IDs
    private static let welcomeID = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
    private static let projectID = UUID(uuidString: "20000000-0000-0000-0000-000000000002")!
    private static let codeReviewID = UUID(uuidString: "30000000-0000-0000-0000-000000000003")!

    public init() {
        setupMockData()
        if Self.verbose {
            Self.logger.info("\(Self.t)MockConversationManager initialized")
        }
    }

    private func setupMockData() {
        if Self.verbose {
            Self.logger.info("\(Self.t)Setting up mock conversations")
        }

        conversations = [
            LumiConversationSummary(
                id: Self.welcomeID,
                title: "Welcome Chat",
                preview: "Hello! How can I help you today?",
                createdAt: Date().addingTimeInterval(-3600),
                updatedAt: Date()
            ),
            LumiConversationSummary(
                id: Self.projectID,
                title: "Project Discussion",
                preview: "Let's talk about the new feature",
                createdAt: Date().addingTimeInterval(-7200),
                updatedAt: Date().addingTimeInterval(-1800)
            ),
            LumiConversationSummary(
                id: Self.codeReviewID,
                title: "Code Review",
                preview: "Can you review this pull request?",
                createdAt: Date().addingTimeInterval(-86400),
                updatedAt: Date().addingTimeInterval(-3600)
            ),
        ]

        selectedConversationID = Self.welcomeID
        updateCurrentTitle()

        if Self.verbose {
            Self.logger.info("\(Self.t)Created \(self.conversations.count) mock conversations")
        }
    }

    private func updateCurrentTitle() {
        guard let selectedID = selectedConversationID,
              let conversation = conversations.first(where: { $0.id == selectedID })
        else {
            if Self.verbose {
                Self.logger.info("\(Self.t)updateCurrentTitle - no conversation selected, setting to 'No conversation'")
            }
            currentTitle = "No conversation"
            return
        }
        let newTitle = conversation.title.isEmpty ? "Untitled" : conversation.title
        if Self.verbose {
            Self.logger.info("\(Self.t)updateCurrentTitle - setting title to: '\(newTitle)'")
        }
        currentTitle = newTitle
    }

    public func createConversation(title: String?) throws -> UUID {
        let now = Date()
        let id = UUID()

        if Self.verbose {
            Self.logger.info("\(Self.t)Creating conversation: \(title ?? "Untitled")")
        }

        let conversation = LumiConversationSummary(
            id: id,
            title: title ?? "New Chat",
            preview: "",
            createdAt: now,
            updatedAt: now
        )

        conversations.insert(conversation, at: 0)
        selectedConversationID = id
        updateCurrentTitle()

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
    }

    public func isSending(for conversationID: UUID?) -> Bool {
        return false
    }

    public func mockConversationIDs() -> [UUID] {
        return [Self.welcomeID, Self.projectID, Self.codeReviewID]
    }
}
