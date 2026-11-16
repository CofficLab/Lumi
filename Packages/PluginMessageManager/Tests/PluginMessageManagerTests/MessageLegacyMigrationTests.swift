import Foundation
import SwiftData
import Testing
import ProviderMessage
@testable import PluginMessageManager

/// v4 历史消息迁移（#394）：升级后旧会话的消息必须随会话一起迁入 v5 消息库。
///
/// ## 背景
///
/// v4→v5 迁移只导入了会话摘要（ConversationLegacyMigration），消息实体留在
/// v4 `Core/Lumi.db`，旧会话打开是空列表、历史也进不了模型上下文。
/// 本套件用 SwiftData 合成一个 v4 旧库（实体名/字段与 v4 完全一致），
/// 验证 MessageLegacyMigration 的导入、去重、marker 与容错契约。
@Suite("v4 历史消息迁移", .serialized)
@MainActor
struct MessageLegacyMigrationTests {
    private let conversationA = UUID()
    private let conversationB = UUID()
    private let baseDate = Date(timeIntervalSince1970: 1_700_000_000)

    // MARK: - Helpers

    private func makeDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MessageLegacyMigration-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    /// 在 `root/Core/Lumi.db` 合成 v4 旧库（子集 schema，实体名与 v4 一致）。
    private func makeV4Database(
        root: URL,
        messages: [ChatMessageEntity],
        attachments: [ImageAttachmentEntity] = []
    ) throws {
        let coreDirectory = root.appendingPathComponent("Core", isDirectory: true)
        try FileManager.default.createDirectory(at: coreDirectory, withIntermediateDirectories: true)
        let dbURL = coreDirectory.appendingPathComponent("Lumi.db")
        let schema = Schema([ChatMessageEntity.self, ImageAttachmentEntity.self])
        let config = ModelConfiguration(schema: schema, url: dbURL, allowsSave: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        for message in messages { context.insert(message) }
        for attachment in attachments { context.insert(attachment) }
        try context.save()
    }

    private func makeStore() throws -> (store: MessageStore, directory: URL) {
        let directory = try makeDirectory()
        return (try MessageStore(databaseRootURL: directory), directory)
    }

    private func runMigration(
        v4Root: URL?,
        store: MessageStore,
        destination: URL
    ) async {
        let migration = MessageLegacyMigration(
            reader: V4MessageReader(v4DataRootDirectory: v4Root),
            store: store,
            destinationRootURL: destination
        )
        await migration.run()
    }

    private func markerExists(at destination: URL) -> Bool {
        let url = destination.appendingPathComponent("migration_state.json")
        guard let data = try? Data(contentsOf: url),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }
        return payload["completed"] as? Bool == true
    }

    /// v4 形状的 toolCallsJSON：结果图片用 `base64Data`（v5 用 `data`），
    /// 并带 v5 已移除的 `turnControl` 键。
    private func v4ToolCallsJSON() throws -> String {
        let payload: [[String: Any]] = [[
            "id": "call_1",
            "name": "read_file",
            "arguments": #"{"path":"a.txt"}"#,
            "displayDescription": "读取 a.txt",
            "result": [
                "content": "file body",
                "duration": 0.5,
                "isError": false,
                "imageAttachments": [[
                    "id": UUID().uuidString,
                    "mimeType": "image/png",
                    "base64Data": "aGk=",
                    "fileName": "x.png",
                ]],
                "turnControl": "continueTurn",
            ] as [String: Any],
        ]]
        let data = try JSONSerialization.data(withJSONObject: payload)
        return String(data: data, encoding: .utf8)!
    }

    // MARK: - Tests

    @Test("迁移保留会话关联、顺序、正文与工具调用/附件/推理内容")
    func migrationImportsMessagesWithOrderAndContent() async throws {
        MessageLegacyMigration.policy = .always
        defer { MessageLegacyMigration.policy = .once }

        let v4Root = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: v4Root) }
        let (store, destination) = try makeStore()
        defer { try? FileManager.default.removeItem(at: destination) }

        let userID = UUID()
        let assistantID = UUID()
        let toolID = UUID()
        let errorID = UUID()
        let otherID = UUID()
        let imageBytes = Data("hi".utf8)

        try makeV4Database(root: v4Root, messages: [
            ChatMessageEntity(
                id: userID, conversationId: conversationA, role: "user", content: "你好",
                timestamp: baseDate, metadataJSON: #"{"k":"v"}"#
            ),
            ChatMessageEntity(
                id: assistantID, conversationId: conversationA, role: "assistant", content: "回复",
                timestamp: baseDate.addingTimeInterval(1),
                providerId: "p1", modelName: "m1",
                toolCallsJSON: v4ToolCallsJSON(), reasoningContent: "思考过程"
            ),
            ChatMessageEntity(
                id: toolID, conversationId: conversationA, role: "tool", content: "file body",
                timestamp: baseDate.addingTimeInterval(2), toolCallID: "call_1"
            ),
            ChatMessageEntity(
                id: errorID, conversationId: conversationA, role: "error", content: "出错了",
                timestamp: baseDate.addingTimeInterval(3),
                isError: true, rawErrorDetail: "boom"
            ),
            ChatMessageEntity(
                id: otherID, conversationId: conversationB, role: "user", content: "另一个会话",
                timestamp: baseDate
            ),
        ], attachments: [
            ImageAttachmentEntity(messageId: userID, data: imageBytes, mimeType: "image/png"),
        ])

        await runMigration(v4Root: v4Root, store: store, destination: destination)

        let messagesA = store.fetchMessages(conversationId: conversationA)
        #expect(messagesA.map(\.id) == [userID, assistantID, toolID, errorID])
        #expect(messagesA.map(\.content) == ["你好", "回复", "file body", "出错了"])
        #expect(messagesA.allSatisfy { $0.conversationID == conversationA })

        let user = try #require(messagesA.first)
        #expect(user.metadata["k"] == "v")
        let images = UserAttachmentMetadata.decodeImageAttachments(from: user.metadata)
        #expect(images.count == 1)
        #expect(images.first?.base64Data == imageBytes.base64EncodedString())
        #expect(images.first?.mimeType == "image/png")

        let assistant = messagesA[1]
        #expect(assistant.reasoningContent == "思考过程")
        #expect(assistant.providerID == "p1")
        #expect(assistant.modelName == "m1")
        let toolCall = try #require(assistant.toolCalls?.first)
        #expect(toolCall.id == "call_1")
        #expect(toolCall.name == "read_file")
        #expect(toolCall.arguments == #"{"path":"a.txt"}"#)
        #expect(toolCall.displayDescription == "读取 a.txt")

        #expect(messagesA[2].toolCallID == "call_1")
        #expect(messagesA[3].isError)
        #expect(messagesA[3].rawErrorDetail == "boom")

        let messagesB = store.fetchMessages(conversationId: conversationB)
        #expect(messagesB.map(\.id) == [otherID])

        #expect(markerExists(at: destination))
    }

    @Test("重复迁移与已存在消息不产生重复数据")
    func repeatMigrationDoesNotDuplicate() async throws {
        MessageLegacyMigration.policy = .always
        defer { MessageLegacyMigration.policy = .once }

        let v4Root = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: v4Root) }
        let (store, destination) = try makeStore()
        defer { try? FileManager.default.removeItem(at: destination) }

        let existingID = UUID()
        let newID = UUID()
        try makeV4Database(root: v4Root, messages: [
            ChatMessageEntity(id: existingID, conversationId: conversationA, role: "user", content: "旧", timestamp: baseDate),
            ChatMessageEntity(id: newID, conversationId: conversationA, role: "assistant", content: "新", timestamp: baseDate.addingTimeInterval(1)),
        ])

        // 新库已含同 id 消息（例如上次迁移残留）：不得再插一份。
        try store.insertMessage(Message(
            id: existingID, conversationID: conversationA, role: .user, content: "旧", createdAt: baseDate
        ))

        await runMigration(v4Root: v4Root, store: store, destination: destination)
        await runMigration(v4Root: v4Root, store: store, destination: destination)

        let messages = store.fetchMessages(conversationId: conversationA)
        #expect(messages.count == 2)
        #expect(Set(messages.map(\.id)) == [existingID, newID])
    }

    @Test("once 策略成功后写 marker，后续启动跳过")
    func oncePolicySkipsAfterSuccessMarker() async throws {
        MessageLegacyMigration.policy = .once
        defer { MessageLegacyMigration.policy = .once }

        let v4Root = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: v4Root) }
        let (store, destination) = try makeStore()
        defer { try? FileManager.default.removeItem(at: destination) }

        let firstID = UUID()
        try makeV4Database(root: v4Root, messages: [
            ChatMessageEntity(id: firstID, conversationId: conversationA, role: "user", content: "第一条", timestamp: baseDate),
        ])
        await runMigration(v4Root: v4Root, store: store, destination: destination)
        #expect(markerExists(at: destination))
        #expect(store.fetchMessages(conversationId: conversationA).count == 1)

        // marker 之后旧库又出现新消息（模拟异常时序）：once 策略不再导入。
        let lateID = UUID()
        try makeV4Database(root: v4Root, messages: [
            ChatMessageEntity(id: lateID, conversationId: conversationA, role: "user", content: "迟到", timestamp: baseDate.addingTimeInterval(5)),
        ])
        await runMigration(v4Root: v4Root, store: store, destination: destination)

        let ids = store.fetchMessages(conversationId: conversationA).map(\.id)
        #expect(ids == [firstID])
    }

    @Test("旧库损坏时吞错、不写 marker、下次启动可重试")
    func corruptLegacyDatabaseDoesNotWriteMarker() async throws {
        MessageLegacyMigration.policy = .once
        defer { MessageLegacyMigration.policy = .once }

        let v4Root = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: v4Root) }
        let (store, destination) = try makeStore()
        defer { try? FileManager.default.removeItem(at: destination) }

        let coreDirectory = v4Root.appendingPathComponent("Core", isDirectory: true)
        try FileManager.default.createDirectory(at: coreDirectory, withIntermediateDirectories: true)
        try Data("not a sqlite database".utf8)
            .write(to: coreDirectory.appendingPathComponent("Lumi.db"))

        await runMigration(v4Root: v4Root, store: store, destination: destination)

        #expect(!markerExists(at: destination))
        #expect(store.fetchMessages(conversationId: conversationA).isEmpty)
    }

    @Test("未知 role 的行被跳过，不阻塞其余消息与 marker")
    func unknownRoleRowsAreSkippedWithoutFailingMigration() async throws {
        MessageLegacyMigration.policy = .always
        defer { MessageLegacyMigration.policy = .once }

        let v4Root = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: v4Root) }
        let (store, destination) = try makeStore()
        defer { try? FileManager.default.removeItem(at: destination) }

        let validID = UUID()
        try makeV4Database(root: v4Root, messages: [
            ChatMessageEntity(id: UUID(), conversationId: conversationA, role: "bogus", content: "未知", timestamp: baseDate),
            ChatMessageEntity(id: validID, conversationId: conversationA, role: "user", content: "有效", timestamp: baseDate.addingTimeInterval(1)),
        ])

        await runMigration(v4Root: v4Root, store: store, destination: destination)

        #expect(store.fetchMessages(conversationId: conversationA).map(\.id) == [validID])
        #expect(markerExists(at: destination))
    }

    @Test("v4 根目录定位：兄弟目录 db_production_v4，缺失返回 nil")
    func locatorFindsSiblingV4Directory() throws {
        let parent = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: parent) }

        let currentRoot = parent.appendingPathComponent("db_production_v5", isDirectory: true)
        #expect(V4MessageDataDirectoryLocator.locate(currentDataRootDirectory: currentRoot) == nil)

        let v4Root = parent.appendingPathComponent("db_production_v4", isDirectory: true)
        try FileManager.default.createDirectory(at: v4Root, withIntermediateDirectories: true)
        #expect(V4MessageDataDirectoryLocator.locate(currentDataRootDirectory: currentRoot) == v4Root)
    }
}