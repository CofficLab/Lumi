import Foundation
import ProviderConversation
import Testing
@testable import PluginConversationManager

/// 回归 #169：会话语言必须随创建与偏好更新写入数据库，
/// 否则重启后 `languageRaw` 为 nil，语言回退全局设置。
@Suite("ConversationLanguagePersistence")
struct ConversationLanguagePersistenceTests {
    private func makeStore() throws -> (ConversationStore, URL) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi-conversation-language-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let store = try ConversationStore(databaseRootURL: dir)
        return (store, dir)
    }

    @Test("创建时传入的语言会被持久化")
    func createPersistsLanguage() async throws {
        let (store, dir) = try makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        let id = UUID()
        let created = try await store.createConversation(
            id: id,
            title: "语言持久化",
            modelID: nil,
            language: .english
        )

        #expect(created.languageRaw == ConversationLanguage.english.rawValue)
        #expect(await store.fetchConversation(id: id)?.language == .english)
    }

    @Test("创建时未传语言则保持为空，读取时回退全局")
    func createWithoutLanguageLeavesNil() async throws {
        let (store, dir) = try makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        let id = UUID()
        try await store.createConversation(id: id, title: "未设置语言", modelID: nil)

        #expect(await store.fetchConversation(id: id)?.language == nil)
    }

    @Test("偏好更新入口可以持久化语言")
    func updateLanguagePersists() async throws {
        let (store, dir) = try makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        let id = UUID()
        try await store.createConversation(id: id, title: "语言更新", modelID: nil, language: .chinese)

        let updated = await store.updateConversationPreferences(id: id, language: .english)
        #expect(updated)
        #expect(await store.fetchConversation(id: id)?.language == .english)
    }
}