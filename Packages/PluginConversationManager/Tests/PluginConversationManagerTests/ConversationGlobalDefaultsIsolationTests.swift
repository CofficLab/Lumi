import Foundation
import ProviderConversation
import Testing
@testable import PluginConversationManager

/// 回归 #786：启动恢复不得把选中会话的配置反写进 New Chat 的全局默认值。
///
/// 全局默认值（详细度/自动化/语言）独立于选中会话，只能从单独落盘的全局值恢复。
/// 旧实现在 `loadConversations()` 里用选中会话的偏好覆盖全局默认，导致新建会话
/// 继承上一个会话的设置，并跨重启持续污染。
@MainActor
@Suite("ConversationGlobalDefaultsIsolation", .serialized)
struct ConversationGlobalDefaultsIsolationTests {
    private func makeDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("ConversationGlobalIsolationTests-\(UUID().uuidString)", isDirectory: true)
    }

    /// 构造「全局默认与选中会话偏好不同」的场景，并等待落盘后模拟重启。
    ///
    /// 全局默认：brief / chat / english；选中会话 A 改为 detailed / autonomous / chinese / high。
    /// 返回重启后的 Manager 与 A 的 ID。
    private func makeRestartedManagerWithDivergedSelection(
        directory: URL
    ) async throws -> (ConversationManager, UUID) {
        let store = try ConversationStore(databaseRootURL: directory)
        let manager = ConversationManager(store: store, dataDirectory: directory)
        manager.setGlobalVerbosity(.brief)
        manager.setGlobalAutomationLevel(.chat)
        manager.setGlobalLanguage(.english)

        let aID = try await manager.createConversationAndWait(
            title: "A",
            projectPath: nil,
            modelID: nil,
            parentConversationID: nil
        )
        // 会话级偏好与全局默认分叉；这些只写会话，不应改写全局默认。
        manager.setVerbosity(.detailed, for: aID)
        manager.setAutomationLevel(.autonomous, for: aID)
        manager.setLanguage(.chinese, for: aID)
        manager.setReasoningEffort(.high, for: aID)

        // 等会话级偏好落库，确保重启后读到的 A 确实是分叉后的配置。
        var persistedA: ConversationSummary?
        for _ in 0..<100 {
            persistedA = await store.fetchConversation(id: aID)
            if persistedA?.verbosity == .detailed,
               persistedA?.automationLevel == .autonomous,
               persistedA?.language == .chinese {
                break
            }
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(persistedA?.verbosity == .detailed)

        // 等 state.json 落盘：选中 A，且全局默认仍是 brief（独立于 A）。
        let stateURL = directory.appendingPathComponent("state.json")
        var stateReady = false
        for _ in 0..<100 {
            if let data = try? Data(contentsOf: stateURL),
               let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               object["selectedConversationID"] as? String == aID.uuidString,
               object["globalVerbosity"] as? String == ResponseVerbosity.brief.rawValue {
                stateReady = true
                break
            }
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(stateReady)

        let restarted = ConversationManager(store: store, dataDirectory: directory)
        restarted.loadConversations()
        for _ in 0..<100 where restarted.isLoadingConversations {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(!restarted.isLoadingConversations)
        return (restarted, aID)
    }

    /// 回归 #786：有选中会话时，重启后的全局默认仍来自独立落盘值，
    /// 而不是被选中会话的 detailed / autonomous / chinese 覆盖。
    @Test func restartWithSelectedConversationKeepsIndependentGlobalDefaults() async throws {
        let directory = makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let (restarted, aID) = try await makeRestartedManagerWithDivergedSelection(directory: directory)

        #expect(restarted.selectedConversationID == aID)
        #expect(restarted.globalVerbosity == .brief)
        #expect(restarted.globalAutomationLevel == .chat)
        #expect(restarted.globalLanguage == .english)
        // 会话级配置仍属于 A 自己，不被全局默认改写。
        #expect(restarted.verbosity(for: aID) == .detailed)
        #expect(restarted.automationLevel(for: aID) == .autonomous)
        #expect(restarted.language(for: aID) == .chinese)
    }

    /// 回归 #786：重启后新建会话 B 继承独立全局默认（brief / chat / english），
    /// 而不是上一个选中会话 A 的 detailed / autonomous / chinese。
    @Test func newConversationAfterRestartInheritsGlobalDefaultsNotSelectedConversation() async throws {
        let directory = makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let (restarted, _) = try await makeRestartedManagerWithDivergedSelection(directory: directory)

        let bID = try await restarted.createConversationAndWait(
            title: "B",
            projectPath: nil,
            modelID: nil,
            parentConversationID: nil
        )

        #expect(restarted.verbosity(for: bID) == .brief)
        #expect(restarted.automationLevel(for: bID) == .chat)
        #expect(restarted.language(for: bID) == .english)
    }

    /// 护栏 #786：运行期修改会话级详细度不得反写 New Chat 的全局默认。
    @Test func changingConversationVerbosityDoesNotRewriteGlobalDefault() {
        let directory = makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let manager = ConversationManager(store: nil, dataDirectory: directory)
        manager.setGlobalVerbosity(.brief)
        let aID = UUID()
        manager.conversations = [ConversationSummary(id: aID, verbosity: .brief)]

        manager.setVerbosity(.detailed, for: aID)

        #expect(manager.globalVerbosity == .brief)
        #expect(manager.verbosity(for: aID) == .detailed)
    }
}