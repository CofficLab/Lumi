import Foundation
import LumiKernel
import SwiftData
import Testing
@testable import LegacyDataPlugin

@Suite("Legacy Data Service Tests")
@MainActor
struct LegacyDataServiceTests {

    // MARK: - Round-trip: write v4 → read via service → verify DTO

    @Test("读取 v4 会话并转换为 LumiConversationSummary(字段全保留)")
    func testFetchConversations() async throws {
        let fixture = try makeV4Fixture(conversations: [
            makeConversation(
                title: "迁移测试会话",
                verbosity: "v3",
                language: "en",
                chatMode: "a2",
                model: "gpt-4o",
                projectId: "/Users/demo/proj"
            )
        ])

        let service = LegacyDataService(v4DataRootDirectory: fixture.rootDirectory)
        #expect(service.hasLegacyData())

        let summaries = try service.fetchLegacyConversations()
        #expect(summaries.count == 1)

        let s = try #require(summaries.first)
        #expect(s.title == "迁移测试会话")
        #expect(s.verbosity == .detailed)        // "v3" → .detailed
        #expect(s.language == .english)          // "en" → .english
        #expect(s.automationLevel == LumiAutomationLevel.build)     // "a2" → .build
        #expect(s.modelName == "gpt-4o")
        #expect(s.projectPath == "/Users/demo/proj")  // v4 projectId → v5 projectPath
        // createdAt/updatedAt 是 Date,应被保留(非当前时间)
        #expect(s.createdAt < Date())

        service.releaseLegacySnapshot()
    }

    @Test("读取 v4 消息并转换为 LumiChatMessage(role/metadata/toolCalls 解码)")
    func testFetchMessages() async throws {
        let convID = UUID()
        let encoder = JSONEncoder()
        let metadataJSON = String(data: try encoder.encode(["k": "v"]), encoding: .utf8)!
        let toolCallsJSON = String(data: try encoder.encode([
            LumiToolCall(id: "call_1", name: "search", arguments: "{}")
        ]), encoding: .utf8)!

        let fixture = try makeV4Fixture(
            conversations: [makeConversation(id: convID, title: "C")],
            messages: [
                makeMessage(conversationID: convID, role: "user", content: "你好", timestamp: 1_700_000_200),
                makeMessage(
                    conversationID: convID,
                    role: "assistant",
                    content: "在的",
                    timestamp: 1_700_000_300,
                    metadataJSON: metadataJSON,
                    toolCallsJSON: toolCallsJSON,
                    toolCallID: "call_1",
                    reasoningContent: "思考中"
                ),
                makeMessage(conversationID: convID, role: "error", content: "出错了", timestamp: 1_700_000_400),
            ]
        )

        let service = LegacyDataService(v4DataRootDirectory: fixture.rootDirectory)
        let messages = try service.fetchLegacyMessages(for: convID)

        #expect(messages.count == 3)
        // 按时间升序
        #expect(messages[0].role == .user)
        #expect(messages[0].content == "你好")
        #expect(messages[1].role == .assistant)
        #expect(messages[1].metadata == ["k": "v"])
        #expect(messages[1].toolCalls?.count == 1)
        #expect(messages[1].toolCalls?.first?.name == "search")
        #expect(messages[1].toolCallID == "call_1")
        #expect(messages[1].reasoningContent == "思考中")
        #expect(messages[2].role == .error)

        service.releaseLegacySnapshot()
    }

    @Test("只读打开:fetch 不修改原件(只读快照契约)")
    func testReadOnlyDoesNotMutateOriginal() async throws {
        let convID = UUID()
        let fixture = try makeV4Fixture(
            conversations: [makeConversation(id: convID, title: "原件")],
            messages: []
        )

        let service = LegacyDataService(v4DataRootDirectory: fixture.rootDirectory)
        _ = try service.fetchLegacyConversations()
        service.releaseLegacySnapshot()

        // 再次用 v4 Model 直接打开原件,数据应完好无损
        let container = try openV4Container(at: fixture.rootDirectory, allowsSave: true)
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<Conversation>()
        let conversations = try context.fetch(descriptor)
        #expect(conversations.count == 1)
        #expect(conversations.first?.title == "原件")
    }

    // MARK: - Edge cases

    @Test("未提供 v4 目录时 hasLegacyData 返回 false")
    func testNoRootDirectory() async throws {
        let service = LegacyDataService(v4DataRootDirectory: nil)
        #expect(service.hasLegacyData() == false)
        #expect(service.legacyDataRootDirectory == nil)
    }

    @Test("v4 目录存在但无数据库文件时 hasLegacyData 返回 false")
    func testRootWithoutDB() async throws {
        let tmp = makeTempDir()
        // 只建了 root,没有 Core/Lumi.db
        let service = LegacyDataService(v4DataRootDirectory: tmp)
        #expect(service.hasLegacyData() == false)
    }

    @Test("fetch 不存在的会话返回空数组")
    func testFetchMessagesForUnknownConversation() async throws {
        let fixture = try makeV4Fixture(
            conversations: [makeConversation(title: "C")],
            messages: []
        )

        let service = LegacyDataService(v4DataRootDirectory: fixture.rootDirectory)
        let messages = try service.fetchLegacyMessages(for: UUID())
        #expect(messages.isEmpty)

        service.releaseLegacySnapshot()
    }

    @Test("releaseLegacySnapshot 幂等:多次调用安全")
    func testReleaseIdempotent() async throws {
        let fixture = try makeV4Fixture(conversations: [])
        let service = LegacyDataService(v4DataRootDirectory: fixture.rootDirectory)
        _ = try service.fetchLegacyConversations()

        service.releaseLegacySnapshot()
        service.releaseLegacySnapshot()  // 再次调用不应崩溃
    }

    @Test("snapshot 复用:连续两次 fetch 使用同一快照")
    func testSnapshotReused() async throws {
        let fixture = try makeV4Fixture(conversations: [
            makeConversation(title: "C1"),
            makeConversation(title: "C2"),
        ])

        let service = LegacyDataService(v4DataRootDirectory: fixture.rootDirectory)
        let first = try service.fetchLegacyConversations()
        let second = try service.fetchLegacyConversations()

        // 复用同一快照,结果一致
        #expect(first.count == 2)
        #expect(second.count == 2)

        service.releaseLegacySnapshot()
    }

    // MARK: - OnBoot hook

    @Test("OnBoot hook 定位 v4 目录并注册服务")
    func testOnBootRegistersService() async throws {
        // 构造一个假的 v5 当前目录 + 真的 v4 兄弟目录
        let parent = makeTempDir()
        let v5Root = parent.appendingPathComponent("db_production_v5", isDirectory: true)
        try FileManager.default.createDirectory(at: v5Root, withIntermediateDirectories: true)
        let v4Root = parent.appendingPathComponent("db_production_v4", isDirectory: true)
        let v4Core = v4Root.appendingPathComponent("Core", isDirectory: true)
        try FileManager.default.createDirectory(at: v4Core, withIntermediateDirectories: true)

        // 在 v4 目录写一个真实的 Lumi.db(空库即可)
        _ = try createV4Store(at: v4Root, conversations: [], messages: [])

        // 用 kernel.storage 指向 v5 目录
        let kernel = LumiKernel()
        kernel.registerService(StorageProviding.self, FakeStorage(dataRootDirectory: v5Root))

        try await LegacyDataOnBootHook().execute(kernel)

        let resolved = kernel.legacyData
        #expect(resolved != nil)
        #expect(resolved?.legacyDataRootDirectory?.lastPathComponent == "db_production_v4")
    }

    @Test("OnBoot hook 无 v4 数据时注册 nil-root 服务(全新安装)")
    func testOnBootNoV4Data() async throws {
        let parent = makeTempDir()
        let v5Root = parent.appendingPathComponent("db_production_v5", isDirectory: true)
        try FileManager.default.createDirectory(at: v5Root, withIntermediateDirectories: true)
        // 不创建 v4 目录

        let kernel = LumiKernel()
        kernel.registerService(StorageProviding.self, FakeStorage(dataRootDirectory: v5Root))

        try await LegacyDataOnBootHook().execute(kernel)

        let resolved = kernel.legacyData
        #expect(resolved != nil)  // 服务仍注册(非 nil),但目录为 nil
        #expect(resolved?.legacyDataRootDirectory == nil)
        #expect(resolved?.hasLegacyData() == false)
    }
}

// MARK: - Test Helpers

/// 临时测试夹具:一个已写入数据的 v4 数据根目录
private struct V4Fixture {
    let rootDirectory: URL
}

/// 用 v4 Model 创建真实的 SwiftData 库并写入数据
@MainActor
private func makeV4Fixture(
    conversations: [Conversation],
    messages: [ChatMessageEntity] = []
) throws -> V4Fixture {
    let root = makeTempDir()
    _ = try createV4Store(at: root, conversations: conversations, messages: messages)
    return V4Fixture(rootDirectory: root)
}

/// 创建 v4 库并写入(用 allowsSave: true,模拟 v4 App 当年的写入)
@MainActor
private func createV4Store(
    at rootDirectory: URL,
    conversations: [Conversation],
    messages: [ChatMessageEntity]
) throws -> ModelContainer {
    let coreDir = rootDirectory.appendingPathComponent("Core", isDirectory: true)
    try FileManager.default.createDirectory(at: coreDir, withIntermediateDirectories: true)
    let dbURL = coreDir.appendingPathComponent("Lumi.db", isDirectory: false)

    let schema = Schema([
        Conversation.self,
        ChatMessageEntity.self,
        ImageAttachmentEntity.self,
        ToolCallEntity.self,
        MessageMetricsEntity.self,
        ChatStateEntity.self,
    ])
    let config = ModelConfiguration(schema: schema, url: dbURL, allowsSave: true, cloudKitDatabase: .none)
    let container = try ModelContainer(for: schema, configurations: [config])

    let context = ModelContext(container)
    for c in conversations { context.insert(c) }
    for m in messages { context.insert(m) }
    try context.save()

    return container
}

/// 用 v4 Model 打开已存在的库(供只读契约测试验证原件未被修改)
@MainActor
private func openV4Container(at rootDirectory: URL, allowsSave: Bool) throws -> ModelContainer {
    let dbURL = rootDirectory
        .appendingPathComponent("Core", isDirectory: true)
        .appendingPathComponent("Lumi.db", isDirectory: false)
    let schema = Schema([
        Conversation.self,
        ChatMessageEntity.self,
        ImageAttachmentEntity.self,
        ToolCallEntity.self,
        MessageMetricsEntity.self,
        ChatStateEntity.self,
    ])
    let config = ModelConfiguration(schema: schema, url: dbURL, allowsSave: allowsSave, cloudKitDatabase: .none)
    return try ModelContainer(for: schema, configurations: [config])
}

private func makeTempDir() -> URL {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("lumi_legacy_test_\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
}

private func makeConversation(
    id: UUID = UUID(),
    title: String,
    preview: String = "",
    verbosity: String? = nil,
    language: String? = nil,
    chatMode: String? = nil,
    model: String? = nil,
    projectId: String? = nil
) -> Conversation {
    Conversation(
        id: id,
        projectId: projectId,
        title: title,
        preview: preview,
        createdAt: Date(timeIntervalSince1970: 1_700_000_000),
        updatedAt: Date(timeIntervalSince1970: 1_700_000_100),
        providerId: nil,
        model: model,
        chatMode: chatMode,
        verbosity: verbosity,
        languagePreference: language
    )
}

private func makeMessage(
    id: UUID = UUID(),
    conversationID: UUID,
    role: String,
    content: String,
    timestamp: TimeInterval = 1_700_000_200,
    metadataJSON: String? = nil,
    toolCallsJSON: String? = nil,
    toolCallID: String? = nil,
    reasoningContent: String? = nil
) -> ChatMessageEntity {
    ChatMessageEntity(
        id: id,
        conversationId: conversationID,
        role: role,
        content: content,
        timestamp: Date(timeIntervalSince1970: timestamp),
        providerId: nil,
        modelName: nil,
        isError: role == "error",
        rawErrorDetail: nil,
        renderKind: nil,
        metadataJSON: metadataJSON,
        toolCallsJSON: toolCallsJSON,
        toolCallID: toolCallID,
        reasoningContent: reasoningContent
    )
}

/// 测试用 StorageProviding,只暴露 dataRootDirectory
@MainActor
private final class FakeStorage: StorageProviding {
    let dataRootDirectory: URL
    init(dataRootDirectory: URL) { self.dataRootDirectory = dataRootDirectory }
    func pluginDataDirectory(for pluginID: String) -> URL {
        dataRootDirectory.appendingPathComponent(pluginID)
    }
    func coreDataDirectory() -> URL {
        dataRootDirectory.appendingPathComponent("Core")
    }
}
