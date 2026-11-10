import Foundation
import KitLLM
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

    @Test func globalChatGPTVerbosityPersistsAcrossRestartWithoutSelectedConversation() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ConversationChatGPTVerbosityPersistenceTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let manager = ConversationManager(store: nil, dataDirectory: directory)
        manager.setGlobalVerbosity(.chatGPT)

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
        #expect(persisted == .chatGPT)

        let store = try ConversationStore(databaseRootURL: directory)
        let restarted = ConversationManager(store: store, dataDirectory: directory)
        restarted.loadConversations()
        for _ in 0..<100 where restarted.isLoadingConversations {
            try await Task.sleep(for: .milliseconds(20))
        }

        #expect(!restarted.isLoadingConversations)
        #expect(restarted.selectedConversationID == nil)
        #expect(restarted.globalVerbosity == .chatGPT)
    }

    /// 回归 #987：后台会话被挤出缓存后，排队回合仍须使用会话绑定的模型。
    @Test func evictedConversationKeepsItsBoundModel() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ConversationModelEvictionTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let manager = ConversationManager(store: nil, dataDirectory: directory)
        let modelID = try #require(LLMModelID(providerID: "gpt-a", modelID: "model-a"))

        let backgroundID = UUID()
        manager.cache(ConversationSummary(
            id: backgroundID,
            createdAt: Date(timeIntervalSince1970: 1),
            modelID: modelID.rawValue
        ))

        // 用 100 条更新的顶层会话把 background 挤出 80 条的有界窗口。
        for index in 0..<100 {
            manager.cache(ConversationSummary(
                id: UUID(),
                createdAt: Date(timeIntervalSince1970: TimeInterval(100 + index))
            ))
        }

        #expect(!manager.conversations.contains { $0.id == backgroundID })
        #expect(manager.modelID(for: backgroundID) == modelID.rawValue)
        #expect(manager.providerID(for: backgroundID) == "gpt-a")
    }

    /// 回归 #1008：后台会话被挤出有界缓存后，仍须使用它自己的自动化级别。
    @Test func evictedConversationKeepsItsAutomationLevel() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ConversationAutomationEvictionTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let manager = ConversationManager(store: nil, dataDirectory: directory)

        let backgroundID = UUID()
        manager.cache(ConversationSummary(
            id: backgroundID,
            createdAt: Date(timeIntervalSince1970: 1),
            automationLevel: .autonomous
        ))

        // 用 100 条更新的顶层会话把 background 挤出 80 条的有界窗口。
        for index in 0..<100 {
            manager.cache(ConversationSummary(
                id: UUID(),
                createdAt: Date(timeIntervalSince1970: TimeInterval(100 + index))
            ))
        }

        #expect(!manager.conversations.contains { $0.id == backgroundID })
        #expect(manager.automationLevel(for: backgroundID) == .autonomous)
    }

    /// 回归 #892：后台会话被挤出有界缓存后，下一次请求仍须使用它自己的推理强度。
    @Test func evictedConversationKeepsItsReasoningEffort() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ConversationReasoningEvictionTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let manager = ConversationManager(store: nil, dataDirectory: directory)

        let backgroundID = UUID()
        manager.cache(ConversationSummary(
            id: backgroundID,
            createdAt: Date(timeIntervalSince1970: 1),
            reasoningEffort: .high
        ))

        // 用 100 条更新的顶层会话把 background 挤出 80 条的有界窗口。
        for index in 0..<100 {
            manager.cache(ConversationSummary(
                id: UUID(),
                createdAt: Date(timeIntervalSince1970: TimeInterval(100 + index))
            ))
        }

        #expect(!manager.conversations.contains { $0.id == backgroundID })
        #expect(manager.reasoningEffortOptional(for: backgroundID) == .high)
    }

    /// 回归 #892：会话已被挤出缓存时设置推理强度，也必须作用于后续请求。
    @Test func evictedConversationUsesReasoningSetWhileMissing() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ConversationReasoningMissingSetTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let manager = ConversationManager(store: nil, dataDirectory: directory)

        let backgroundID = UUID()
        manager.cache(ConversationSummary(
            id: backgroundID,
            createdAt: Date(timeIntervalSince1970: 1),
            reasoningEffort: .low
        ))
        for index in 0..<100 {
            manager.cache(ConversationSummary(
                id: UUID(),
                createdAt: Date(timeIntervalSince1970: TimeInterval(100 + index))
            ))
        }
        #expect(!manager.conversations.contains { $0.id == backgroundID })

        manager.setReasoningEffort(.max, for: backgroundID)

        #expect(manager.reasoningEffortOptional(for: backgroundID) == .max)
    }

    /// 护栏 #892：在缓存外清除推理强度后，不能残留淘汰前的旧档位。
    @Test func clearedReasoningOnEvictedConversationStaysOff() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ConversationReasoningClearTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let manager = ConversationManager(store: nil, dataDirectory: directory)

        let backgroundID = UUID()
        manager.cache(ConversationSummary(
            id: backgroundID,
            createdAt: Date(timeIntervalSince1970: 1),
            reasoningEffort: .high
        ))
        for index in 0..<100 {
            manager.cache(ConversationSummary(
                id: UUID(),
                createdAt: Date(timeIntervalSince1970: TimeInterval(100 + index))
            ))
        }
        #expect(!manager.conversations.contains { $0.id == backgroundID })

        manager.clearReasoningEffort(for: backgroundID)

        #expect(manager.reasoningEffortOptional(for: backgroundID) == nil)
    }

    /// 护栏 #892：从未见过的会话仍是「没有显式档位」，不能被其他会话污染。
    @Test func unknownConversationHasNoReasoningEffort() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ConversationReasoningUnknownTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let manager = ConversationManager(store: nil, dataDirectory: directory)
        manager.cache(ConversationSummary(
            id: UUID(),
            createdAt: Date(timeIntervalSince1970: 1),
            reasoningEffort: .high
        ))

        #expect(manager.reasoningEffortOptional(for: nil) == nil)
        #expect(manager.reasoningEffortOptional(for: UUID()) == nil)
    }

    /// 护栏 #1008：缓存外仍未知的会话不能被其他会话的级别污染，nil 仍回退 Build。
    @Test func unknownConversationStillDefaultsToBuild() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ConversationAutomationUnknownTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let manager = ConversationManager(store: nil, dataDirectory: directory)
        manager.cache(ConversationSummary(
            id: UUID(),
            createdAt: Date(timeIntervalSince1970: 1),
            automationLevel: .autonomous
        ))

        #expect(manager.automationLevel(for: nil) == .build)
        #expect(manager.automationLevel(for: UUID()) == .build)
    }
}
