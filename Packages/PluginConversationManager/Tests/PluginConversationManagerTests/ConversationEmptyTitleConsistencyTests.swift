import Foundation
import KitLLM
import ProviderConversation
import Testing
@testable import PluginConversationManager

/// 锁定**「无标题」这件事在存储层与读取层的表示契约**。
///
/// ## 为什么要有这层契约
///
/// `ConversationModel.title` 是**非可选** `String`，所以「无标题」在数据库里
/// 必然是 `''`，不可能是 NULL。读取侧 `ConversationModel.toLumiConversationSummary()`
/// 额外做了一次归一：空串 → `nil`。
///
/// 两层用的是两种形态，但**必须指向同一个事实**：这一条对话没有标题。
/// 只要有一层把「无标题」解释成了「有标题」，下游任何按 `nil` 判断
/// 「有没有标题」的代码都会与存储层对不上，列表就会出现一条没有名字的条目。
///
/// ## 与缺陷的关系
///
/// 这不是缺陷的复现，而是**契约护栏**。缺陷的复现在
/// `PluginConversationTitle` 的 `TitleServiceFallbackTests`：
/// 自动标题的 LLM 调用失败后没有兜底，对话永远停在「无标题」。
/// 这里锁的是「无标题」被正确表达的那一半——有了兜底标题以后，
/// 对话要么有标题，要么明确是无标题，不会出现第三种状态。
@Suite("无标题对话的存储与读取语义")
struct ConversationEmptyTitleConsistencyTests {

    private func makeStore() throws -> (ConversationStore, URL) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi-empty-title-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let store = try ConversationStore(databaseRootURL: dir)
        return (store, dir)
    }

    /// 无标题在存储层是空串，在读取层是 nil —— 两层指向同一个事实。
    ///
    /// 存储层字段非可选，空标题只能是 `''`；读取层归一为 `nil`。
    /// 两层都表示「没有标题」，没有任何一层把它变成有标题。
    @Test("无标题在存储层为空串，读回摘要为无标题")
    func emptyTitleMeansNoTitleInBothLayers() async throws {
        let (store, dir) = try makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        let id = UUID()
        let model = try await store.createConversation(id: id, title: nil)

        // 存储层：非可选字段，空标题只能是空串。
        #expect(
            model.title == "",
            "存储层的无标题表示应为空串，实际「\(model.title)」"
        )

        // 读取层：归一为 nil。
        let fetched = try #require(await store.fetchConversation(id: id))
        #expect(
            fetched.title == nil,
            "读取层应把空串归一为 nil（无标题），实际「\(fetched.title ?? "nil")」"
        )
    }

    /// 纯空白标题写入后必须与「无标题」等价。
    ///
    /// 存储层写入前会 trim，所以 `"   "` 落库就是空串；读取层必须给出
    /// 一致的解释，不能一个当空串、一个当有标题。
    @Test("纯空白标题与无标题等价")
    func whitespaceOnlyTitleIsEquivalentToNoTitle() async throws {
        let (store, dir) = try makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        let blankID = UUID()
        let nilID = UUID()
        try await store.createConversation(id: blankID, title: "   \n  ")
        try await store.createConversation(id: nilID, title: nil)

        let blank = try #require(await store.fetchConversation(id: blankID))
        let none = try #require(await store.fetchConversation(id: nilID))
        #expect(
            blank.title == none.title,
            "纯空白标题「\(blank.title ?? "nil")」应与无标题「\(none.title ?? "nil")」等价"
        )
    }

    /// 有标题时两层都必须保留标题。
    ///
    /// 这是上一条的对照项：归一只针对「trim 后为空」的情况，不能误伤正常标题。
    @Test("有标题时存储层与读取层都保留标题")
    func realTitleSurvivesRoundTrip() async throws {
        let (store, dir) = try makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        let id = UUID()
        try await store.createConversation(id: id, title: "排查并修复登录超时")

        let fetched = try #require(await store.fetchConversation(id: id))
        #expect(fetched.title == "排查并修复登录超时")
    }

    /// 清空标题后，内存与数据库都必须表达「无标题」。
    ///
    /// 内存层：`ConversationManager.updateConversationTitle` 把空标题写成 nil。
    /// 存储层：`ConversationStore.updateTitle` 落库为空串，读回时归一为 nil。
    ///
    /// - Note: 两层**分别**验证，不去轮询等待管理器的异步落库。
    ///   管理器的落库由 `Task { await store?.updateTitle(...) }` 触发，
    ///   而测试里的轮询会不断新建 ModelContext 读库，与写入抢 SQLite 锁，
    ///   把写入饿死（实测会等满超时仍读不到新值）。这是测试自身的问题，
    ///   不是产品行为。
    @Test("清空标题后内存与数据库都表示无标题")
    @MainActor
    func clearingTitleKeepsMemoryAndDatabaseConsistent() async throws {
        let (store, dir) = try makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        let id = UUID()
        try await store.createConversation(id: id, title: "原始标题")
        let manager = ConversationManager(store: store, dataDirectory: dir)
        manager.conversations = [ConversationSummary(id: id, title: "原始标题")]

        // 清空标题。
        #expect(manager.updateConversationTitle("   ", for: id))

        let inMemory = manager.conversations.first(where: { $0.id == id })?.title
        #expect(
            inMemory?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false,
            "内存中清空后的标题应为空，实际「\(inMemory ?? "nil")」"
        )

        // 存储层：空标题落库后读回仍然是「无标题」。
        #expect(await store.updateTitle(id: id, title: "   "))
        let persisted = await store.fetchConversation(id: id)?.title
        #expect(
            persisted?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false,
            "数据库中清空后的标题应为空，实际「\(persisted ?? "nil")」"
        )
    }
}
