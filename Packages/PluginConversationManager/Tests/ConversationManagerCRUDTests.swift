import Foundation
import ProviderConversation
import Testing
@testable import PluginConversationManager

@MainActor
@Suite(.serialized)
struct ConversationManagerCRUDTests {
    @Test func creationInheritsGlobalPreferencesAndKeepsChildOutOfRootCache() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ConversationCreationTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let manager = ConversationManager(store: nil, dataDirectory: directory)
        manager.setGlobalVerbosity(.brief)
        manager.setGlobalReasoningEffort(.low)
        manager.setGlobalAutomationLevel(.autonomous)
        manager.setGlobalLanguage(.english)
        var events: [ConversationEvent] = []
        let handle = manager.addConversationObserver { events.append($0) }
        defer { handle.cancel() }

        let rootID = try manager.createConversation(
            title: "  Root conversation  ",
            projectPath: nil,
            providerID: nil,
            modelName: nil
        )
        let root = try #require(manager.conversations.first)
        #expect(root.id == rootID)
        #expect(root.title == "Root conversation")
        #expect(root.verbosity == .brief)
        #expect(root.reasoningEffort == .low)
        #expect(root.automationLevel == .autonomous)
        #expect(root.language == .english)
        #expect(manager.selectedConversationID == rootID)
        #expect(manager.currentTitle == "Root conversation")

        let childID = try manager.createConversation(
            title: "Sub-agent",
            projectPath: nil,
            providerID: nil,
            modelName: nil,
            parentConversationID: rootID
        )
        #expect(manager.conversations.map(\.id) == [rootID])
        #expect(manager.selectedConversationID == rootID)
        #expect(events.contains(.created(rootID)))
        #expect(!events.contains(.created(childID)))

        try await Task.sleep(for: .milliseconds(20))
    }

    /// 回归 #541：等待落库的创建接口返回时，会话必须已经能从库里读到。
    @Test func createAndWaitPersistsBeforeReturningAndCachesRoot() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ConversationCreateAndWait-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = try ConversationStore(databaseRootURL: directory)
        let manager = ConversationManager(store: store, dataDirectory: directory)

        let id = try await manager.createConversationAndWait(
            title: "Waited",
            projectPath: nil,
            modelID: nil,
            parentConversationID: nil
        )

        // 不 sleep：返回即代表已落库。
        let stored = await store.fetchConversation(id: id)
        #expect(stored?.title == "Waited")
        #expect(manager.conversations.contains(where: { $0.id == id }))
        #expect(manager.selectedConversationID == id)
    }

    @Test func selectionTitleActivityAndDeletionUpdateCachedStateAndEvents() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ConversationCRUDTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let manager = ConversationManager(store: nil, dataDirectory: directory)
        let firstID = UUID()
        let secondID = UUID()
        manager.conversations = [
            ConversationSummary(id: firstID, title: "First"),
            ConversationSummary(id: secondID, title: "Second"),
        ]
        var selectedIDs: [UUID?] = []
        var selectedEventTitles: [String] = []
        var events: [ConversationEvent] = []
        let selectedHandle = manager.addSelectedConversationObserver { selectedIDs.append($0) }
        let eventHandle = manager.addConversationObserver { event in
            events.append(event)
            if case .selected = event {
                selectedEventTitles.append(manager.currentTitle)
            }
        }
        defer {
            selectedHandle.cancel()
            eventHandle.cancel()
        }

        manager.selectConversation(id: firstID)
        #expect(manager.currentTitle == "First")
        #expect(selectedIDs == [firstID])
        #expect(selectedEventTitles == ["First"])

        #expect(manager.updateConversationTitle("   ", for: firstID))
        #expect(manager.conversations.first(where: { $0.id == firstID })?.title == nil)
        #expect(manager.currentTitle == "Untitled")
        #expect(!manager.updateConversationTitle("missing", for: UUID()))
        #expect(manager.updateConversationTitle("Restored title", for: firstID))
        #expect(manager.currentTitle == "Restored title")

        let messageDate = Date(timeIntervalSince1970: 2_000_000_000)
        manager.markConversationActive(id: secondID, messageDate: messageDate)
        #expect(manager.conversations.first(where: { $0.id == secondID })?.lastMessageAt == messageDate)
        #expect(manager.sortedConversations.first?.id == secondID)

        manager.selectConversation(id: secondID)
        #expect(selectedEventTitles == ["First", "Second"])
        manager.deleteConversation(id: secondID)
        #expect(manager.conversations.map(\.id) == [firstID])
        #expect(manager.selectedConversationID == firstID)
        #expect(manager.currentTitle == "Restored title")
        manager.deleteConversation(id: UUID())
        #expect(manager.conversations.map(\.id) == [firstID])
        #expect(!manager.isSending(for: firstID))
        #expect(events.contains(.updated(firstID)))
        #expect(events.contains(.markedActive(secondID)))
        #expect(events.contains(.deleted(secondID)))

        try await Task.sleep(for: .milliseconds(20))
    }

    /// 回归 #771：父会话删除时，子会话也会被连带删掉，观察者（例如
    /// GoalTask）必须收到子会话的 `.deleted`，否则子会话的 Goals 会残留。
    @Test func deletingRootNotifiesDescendantConversations() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ConversationDescendantDelete-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = try ConversationStore(databaseRootURL: directory)
        let manager = ConversationManager(store: store, dataDirectory: directory)

        var events: [ConversationEvent] = []
        let handle = manager.addConversationObserver { events.append($0) }
        defer { handle.cancel() }

        let rootID = try await manager.createConversationAndWait(
            title: "Root",
            projectPath: nil,
            modelID: nil,
            parentConversationID: nil
        )
        let childID = try await manager.createConversationAndWait(
            title: "Child",
            projectPath: nil,
            modelID: nil,
            parentConversationID: rootID
        )

        manager.deleteConversation(id: rootID)
        for _ in 0..<100 where !events.contains(.deleted(childID)) {
            try await Task.sleep(for: .milliseconds(20))
        }

        #expect(events.contains(.deleted(rootID)))
        #expect(events.contains(.deleted(childID)))
    }
}
