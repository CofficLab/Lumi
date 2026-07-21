import Foundation
import LumiKernel

/// Mock conversation manager with sample data for testing
@MainActor
public final class MockConversationManager: ObservableObject, ConversationManaging {
    @Published public private(set) var conversations: [LumiConversationSummary] = []
    @Published public private(set) var selectedConversationID: UUID?

    public var dataDirectory: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("MockConversations")
    }

    // Fixed mock IDs for testing - MessageManager uses these same IDs
    private static let welcomeID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private static let projectID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    private static let codeReviewID = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!

    public init() {
        setupMockData()
    }

    private func setupMockData() {
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
    }

    public func createConversation(title: String?) throws -> UUID {
        let now = Date()
        let id = UUID()

        let conversation = LumiConversationSummary(
            id: id,
            title: title ?? "New Chat",
            preview: "",
            createdAt: now,
            updatedAt: now
        )

        conversations.insert(conversation, at: 0)
        selectedConversationID = id

        return id
    }

    public func selectConversation(id: UUID) {
        selectedConversationID = id
    }

    public func deleteConversation(id: UUID) {
        conversations.removeAll { $0.id == id }

        if selectedConversationID == id {
            selectedConversationID = conversations.first?.id
        }
    }

    public func isSending(for conversationID: UUID?) -> Bool {
        return false
    }

    public func mockConversationIDs() -> [UUID] {
        [Self.welcomeID, Self.projectID, Self.codeReviewID]
    }
}
