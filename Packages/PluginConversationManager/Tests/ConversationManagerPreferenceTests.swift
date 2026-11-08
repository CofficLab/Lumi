import Foundation
import ProviderConversation
import Testing
@testable import PluginConversationManager

@MainActor
@Suite(.serialized)
struct ConversationManagerPreferenceTests {
    @Test func automationPreferenceDoesNotPublishStructuralListChange() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ConversationAutomationTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let manager = ConversationManager(store: nil, dataDirectory: directory)
        let conversationID = UUID()
        manager.conversations = [ConversationSummary(id: conversationID, automationLevel: .chat)]
        var events: [ConversationEvent] = []
        let handle = manager.addConversationObserver { events.append($0) }
        defer { handle.cancel() }

        manager.setAutomationLevel(.autonomous, for: conversationID)

        #expect(events == [.automationChanged(conversationID)])
        #expect(manager.automationLevel(for: conversationID) == .autonomous)
    }

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

    /// 回归 #983：New Chat 的默认回复语言没有会话承载，必须跨重启保留。
    @Test func globalLanguagePersistsAcrossRestartWithoutSelectedConversation() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ConversationLanguagePersistenceTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let manager = ConversationManager(store: nil, dataDirectory: directory)
        manager.setGlobalLanguage(.english)

        // 写盘在串行队列上异步完成，等 state.json 落盘后再模拟重启。
        let stateURL = directory.appendingPathComponent("state.json")
        var persisted: ConversationLanguage?
        for _ in 0..<100 {
            if let data = try? Data(contentsOf: stateURL),
               let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let raw = object["globalLanguage"] as? String,
               let language = ConversationLanguage(rawValue: raw) {
                persisted = language
                break
            }
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(persisted == .english)

        let store = try ConversationStore(databaseRootURL: directory)
        let restarted = ConversationManager(store: store, dataDirectory: directory)
        restarted.loadConversations()
        for _ in 0..<100 where restarted.isLoadingConversations {
            try await Task.sleep(for: .milliseconds(20))
        }

        #expect(!restarted.isLoadingConversations)
        #expect(restarted.selectedConversationID == nil)
        #expect(restarted.globalLanguage == .english)
    }

    /// 回归 #984：后台会话被挤出有界缓存后，请求仍应使用该会话自己的语言。
    @Test func evictedConversationKeepsItsOwnLanguage() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ConversationLanguageEvictionTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let manager = ConversationManager(store: nil, dataDirectory: directory)
        manager.setGlobalLanguage(.chinese)

        let backgroundID = UUID()
        manager.cache(ConversationSummary(
            id: backgroundID,
            createdAt: Date(timeIntervalSince1970: 1),
            language: .english
        ))

        // 用 100 条更新的顶层会话把 background 挤出 80 条的有界窗口。
        for index in 0..<100 {
            manager.cache(ConversationSummary(
                id: UUID(),
                createdAt: Date(timeIntervalSince1970: TimeInterval(100 + index))
            ))
        }

        #expect(!manager.conversations.contains { $0.id == backgroundID })
        #expect(manager.globalLanguage == .chinese)
        #expect(manager.language(for: backgroundID) == .english)
    }

    /// 回归 #986：New Chat 的默认详细度没有会话承载，必须跨重启保留。
    @Test func globalVerbosityPersistsAcrossRestartWithoutSelectedConversation() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ConversationVerbosityPersistenceTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let manager = ConversationManager(store: nil, dataDirectory: directory)
        manager.setGlobalVerbosity(.brief)

        // 写盘在串行队列上异步完成，等 state.json 落盘后再模拟重启。
        let stateURL = directory.appendingPathComponent("state.json")
        var persisted: ResponseVerbosity?
        for _ in 0..<100 {
            if let data = try? Data(contentsOf: stateURL),
               let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let raw = object["globalVerbosity"] as? String,
               let verbosity = ResponseVerbosity(rawValue: raw) {
                persisted = verbosity
                break
            }
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(persisted == .brief)

        let store = try ConversationStore(databaseRootURL: directory)
        let restarted = ConversationManager(store: store, dataDirectory: directory)
        restarted.loadConversations()
        for _ in 0..<100 where restarted.isLoadingConversations {
            try await Task.sleep(for: .milliseconds(20))
        }

        #expect(!restarted.isLoadingConversations)
        #expect(restarted.selectedConversationID == nil)
        #expect(restarted.globalVerbosity == .brief)
    }
}
