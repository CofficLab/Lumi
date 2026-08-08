import Foundation
import LumiKernel
import Testing
@testable import ConversationManagerPlugin

@Suite("ConversationManagerPlugin")
@MainActor
struct ConversationManagerPluginTests {
    @Test("new conversations inherit the global reasoning setting")
    func newConversationsInheritGlobalReasoningSetting() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ConversationManagerPluginTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }

        let service = try ConversationService(storageDirectory: directory)
        service.deselectConversation()

        service.setGlobalReasoningEffort(.xhigh)
        let enabledConversationID = try service.createConversation(
            title: nil,
            projectPath: nil,
            providerID: nil,
            modelName: nil
        )
        #expect(service.reasoningEffortOptional(for: enabledConversationID) == .xhigh)

        service.deselectConversation()
        service.setGlobalReasoningEffort(nil)
        let disabledConversationID = try service.createConversation(
            title: nil,
            projectPath: nil,
            providerID: nil,
            modelName: nil
        )
        #expect(service.reasoningEffortOptional(for: disabledConversationID) == nil)
    }

    @Test("new conversations inherit the global conversation mode")
    func newConversationsInheritGlobalConversationMode() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ConversationManagerPluginTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }

        let service = try ConversationService(storageDirectory: directory)
        service.deselectConversation()
        service.setGlobalAutomationLevel(.autonomous)

        let conversationID = try service.createConversation(
            title: nil,
            projectPath: nil,
            providerID: nil,
            modelName: nil
        )

        #expect(service.automationLevel(for: conversationID) == .autonomous)
    }
}
