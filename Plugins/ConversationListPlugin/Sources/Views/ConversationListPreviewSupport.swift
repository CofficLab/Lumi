#if DEBUG
import Combine
import Foundation
import LumiKernel

/// Mock ConversationManaging for DEBUG previews
@MainActor
final class MockConversationManaging: ObservableObject, ConversationManaging {
    @Published var conversations: [LumiConversationSummary] = []
    @Published var selectedConversationID: UUID?
    var currentTitle: String { "" }
    var dataDirectory: URL { URL(fileURLWithPath: NSTemporaryDirectory()) }

    func createConversation(title: String?) throws -> UUID {
        let id = UUID()
        let conv = LumiConversationSummary(
            id: id,
            title: title ?? "New Chat",
            preview: "",
            createdAt: Date(),
            updatedAt: Date(),
            providerID: nil,
            modelName: nil,
            projectPath: nil
        )
        conversations.insert(conv, at: 0)
        return id
    }

    func selectConversation(id: UUID) {
        selectedConversationID = id
    }

    func deleteConversation(id: UUID) {
        conversations.removeAll { $0.id == id }
        if selectedConversationID == id {
            selectedConversationID = conversations.first?.id
        }
    }

    func isSending(for conversationID: UUID?) -> Bool { false }
    func mockConversationIDs() -> [UUID] { [] }
    func providerID(for conversationID: UUID?) -> String? { nil }
    func modelName(for conversationID: UUID?) -> String? { nil }
    func selectProvider(id: String, model: String?, for conversationID: UUID?) {}
    func verbosity(for conversationID: UUID?) -> LumiResponseVerbosity { .standard }
    func setVerbosity(_ verbosity: LumiResponseVerbosity, for conversationID: UUID?) {}
    func automationLevel(for conversationID: UUID?) -> LumiAutomationLevel { .chat }
    func setAutomationLevel(_ automationLevel: LumiAutomationLevel, for conversationID: UUID?) {}
}

enum ConversationListPreviewSupport {
    @MainActor
    static func makeContext() -> ConversationListContext {
        let mock = MockConversationManaging()
        for i in 0..<5 {
            _ = try? mock.createConversation(title: "Sample Conversation \(i + 1)")
        }
        return ConversationListContext(conversationManaging: mock)
    }
}
#endif
