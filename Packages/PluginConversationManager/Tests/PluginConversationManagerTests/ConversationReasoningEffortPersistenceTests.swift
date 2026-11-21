import Foundation
import ProviderConversation
import Testing
@testable import PluginConversationManager

/// 回归 #597：New Chat（无选中会话）里设置的默认推理强度必须单独落盘，
/// 跨重启保留并被子会话继承。
///
/// `globalReasoningEffort` 的 nil 与「用户显式关闭思考」重合，因此 state.json
/// 用 `hasGlobalReasoningEffort` 存在标记表达三态：
/// 缺键（旧版本文件）→ 保持出厂默认；true + nil → 显式关闭；true + 档位 → 用户档位。
@MainActor
@Suite("ConversationReasoningEffortPersistence", .serialized)
struct ConversationReasoningEffortPersistenceTests {
    private func makeDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("ConversationReasoningEffortTests-\(UUID().uuidString)", isDirectory: true)
    }

    /// 轮询等待 state.json 落盘并包含推理强度字段（写入在 utility 队列异步执行）。
    private func waitForEffortPersisted(in directory: URL) async throws -> Bool {
        let url = directory.appendingPathComponent("state.json")
        for _ in 0..<100 {
            if let data = try? Data(contentsOf: url),
               let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               object["hasGlobalReasoningEffort"] as? Bool == true {
                return true
            }
            try await Task.sleep(for: .milliseconds(20))
        }
        return false
    }

    private func waitForLoaded(_ manager: ConversationManager) async throws {
        manager.loadConversations()
        for _ in 0..<100 where manager.isLoadingConversations {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(!manager.isLoadingConversations)
    }

    @Test("用户选择的默认档位跨重启保留，并被子会话继承")
    func chosenEffortSurvivesRestartAndInheritsIntoNewConversation() async throws {
        let directory = makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = try ConversationStore(databaseRootURL: directory)
        let manager = ConversationManager(store: store, dataDirectory: directory)
        manager.setGlobalReasoningEffort(.low)
        #expect(try await waitForEffortPersisted(in: directory), "state.json 应已包含推理强度字段")

        let restarted = ConversationManager(store: store, dataDirectory: directory)
        try await waitForLoaded(restarted)
        #expect(restarted.globalReasoningEffort == .low)

        let newID = try await restarted.createConversationAndWait(
            title: "B",
            projectPath: nil,
            modelID: nil,
            parentConversationID: nil
        )
        #expect(restarted.reasoningEffortOptional(for: newID) == .low, "新建会话应继承重启后恢复的全局默认档位")
    }

    @Test("用户显式关闭思考（nil）跨重启保留")
    func explicitOffSurvivesRestart() async throws {
        let directory = makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = try ConversationStore(databaseRootURL: directory)
        let manager = ConversationManager(store: store, dataDirectory: directory)
        manager.setGlobalReasoningEffort(nil)
        #expect(try await waitForEffortPersisted(in: directory), "state.json 应已包含推理强度字段")

        let restarted = ConversationManager(store: store, dataDirectory: directory)
        try await waitForLoaded(restarted)
        #expect(restarted.globalReasoningEffort == nil, "显式关闭不得被恢复成出厂默认 .high")
    }

    @Test("旧版本 state.json 缺推理强度键时保持出厂默认")
    func legacyStateFileWithoutEffortKeyKeepsDefaultEffort() async throws {
        let directory = makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        // 手写一份 #597 修复之前的 state.json（不含 hasGlobalReasoningEffort）。
        let legacyState: [String: Any] = [
            "selectedConversationID": NSNull(),
            "globalVerbosity": ResponseVerbosity.brief.rawValue,
            "globalLanguage": ConversationLanguage.english.rawValue,
            "globalAutomationLevel": AutomationLevel.build.rawValue
        ]
        let data = try JSONSerialization.data(withJSONObject: legacyState)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: directory.appendingPathComponent("state.json"), options: .atomic)

        let store = try ConversationStore(databaseRootURL: directory)
        let restarted = ConversationManager(store: store, dataDirectory: directory)
        try await waitForLoaded(restarted)
        #expect(restarted.globalReasoningEffort == .defaultEffort, "缺键的旧文件不得被当成显式关闭")
    }
}
