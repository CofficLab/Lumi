import Foundation
import ProviderConversation
import Testing
@testable import PluginConversationManager

@MainActor
@Suite(.serialized)
struct ConversationManagerPreferenceTests {
    @Test func globalAndConversationPreferencesUpdateCacheAndNotifyObservers() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ConversationPreferenceTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let manager = ConversationManager(store: nil, dataDirectory: directory)
        let conversationID = UUID()
        let olderID = UUID()
        let olderDate = Date(timeIntervalSince1970: 10)
        let newerDate = Date(timeIntervalSince1970: 20)
        manager.conversations = [
            ConversationSummary(id: olderID, title: "older", createdAt: olderDate, lastMessageAt: olderDate),
            ConversationSummary(
                id: conversationID,
                title: "newer",
                createdAt: olderDate,
                lastMessageAt: newerDate,
                verbosity: .standard,
                reasoningEffort: .low,
                automationLevel: .chat,
                providerID: "openai",
                modelName: "gpt"
            ),
        ]

        var events: [ConversationEvent] = []
        let handle = manager.addConversationObserver { events.append($0) }
        defer { handle.cancel() }

        manager.setGlobalVerbosity(.brief)
        manager.setGlobalReasoningEffort(.medium)
        manager.setGlobalAutomationLevel(.autonomous)
        manager.setGlobalLanguage(.english)
        manager.selectProvider(id: "anthropic", model: "claude", for: conversationID)
        manager.setVerbosity(.detailed, for: conversationID)
        manager.setReasoningEffort(.max, for: conversationID)
        manager.clearReasoningEffort(for: conversationID)
        manager.setAutomationLevel(.build, for: conversationID)
        manager.setLanguage(.english, for: conversationID)
        await manager.setVerbosityAndWait(.brief, for: conversationID)

        #expect(manager.globalVerbosity == .brief)
        #expect(manager.globalReasoningEffort == .medium)
        #expect(manager.globalAutomationLevel == .autonomous)
        #expect(manager.globalLanguage == .english)
        #expect(manager.verbosity(for: conversationID) == .brief)
        #expect(manager.reasoningEffortOptional(for: conversationID) == nil)
        #expect(manager.automationLevel(for: conversationID) == .build)
        #expect(manager.language(for: conversationID) == .english)
        #expect(manager.providerID(for: conversationID) == "anthropic")
        #expect(manager.modelName(for: conversationID) == "claude")
        #expect(manager.sortedConversations.map(\.id) == [conversationID, olderID])

        #expect(events.contains(.verbosityChanged(nil)))
        #expect(events.contains(.reasoningChanged(nil)))
        #expect(events.contains(.automationChanged(nil)))
        #expect(events.contains(.languageChanged(nil)))
        #expect(events.contains(.providerChanged(conversationID)))
        #expect(events.contains(.verbosityChanged(conversationID)))
        #expect(events.contains(.reasoningChanged(conversationID)))
        #expect(events.contains(.automationChanged(conversationID)))
        #expect(events.contains(.languageChanged(conversationID)))
    }
}
