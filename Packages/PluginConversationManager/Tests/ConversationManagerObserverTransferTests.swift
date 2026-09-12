import Foundation
import ProviderConversation
import Testing
@testable import PluginConversationManager

@MainActor
@Suite(.serialized)
struct ConversationManagerObserverTransferTests {
    @Test func transferredObserversStayAliveAndCancelWithTheirOriginalHandles() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ConversationObserverTransferTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let original = ConversationManager(store: nil, dataDirectory: directory.appendingPathComponent("original"))
        let replacement = ConversationManager(store: nil, dataDirectory: directory.appendingPathComponent("replacement"))
        var selectedValues: [UUID?] = []
        var conversationEventCount = 0
        let selectedHandle = original.addSelectedConversationObserver { selectedValues.append($0) }
        let conversationHandle = original.addConversationObserver { _ in conversationEventCount += 1 }

        original.transferObservers(to: replacement)
        let finalManager = ConversationManager(store: nil, dataDirectory: directory.appendingPathComponent("final"))
        replacement.transferObservers(to: finalManager)
        let selectedID = UUID()
        finalManager.selectConversation(id: selectedID)
        finalManager.setGlobalVerbosity(.brief)

        #expect(selectedValues == [selectedID])
        #expect(conversationEventCount > 0)
        let deliveredEventCount = conversationEventCount

        selectedHandle.cancel()
        conversationHandle.cancel()
        finalManager.deselectConversation()
        finalManager.setGlobalReasoningEffort(nil)

        #expect(selectedValues == [selectedID])
        #expect(conversationEventCount == deliveredEventCount)
    }
}
