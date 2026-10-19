#if DEBUG
import Foundation
import ProviderConversation
import ProviderMessage
import Testing
@testable import PluginMessageListEmpty

/// UI 测试夹具的 seed 行为验证（不启动 App）。
///
/// ## 为什么需要这一层
///
/// 夹具 `MessageListEmptyUITestingSupport` 的产物是 UI 测试的**唯一**数据源。
/// 一旦它没种出预期结构，UI 层只会报「空态未出现」或「活动条未出现」——
/// 指向渲染或定位失败，而真实原因是**数据根本没种对**。两层混在一起时，
/// 归因必然出错，且极易把夹具缺陷误判成产品缺陷。
///
/// 这里在纯内存层面断言 seed 的产物，把「数据问题」与「渲染/定位问题」分开。
///
/// - Important: 夹具整体位于 `#if DEBUG`，因此**整个文件**（含 import）
///   同样包裹。少了这个守卫，`swift build -c release` 会因找不到该类型而
///   失败，而本地 Debug 通过完全掩盖不了这一点。
@MainActor
@Suite("MessageListEmpty UI fixture")
struct MessageListEmptyUITestingSupportTests {
    /// 夹具在历史会话里植入的消息总数：4 个日期 ×（user + assistant）。
    private static let historyMessageCount = 8
    /// tool-only 会话里的消息数。
    private static let toolOnlyMessageCount = 1

    /// 建好三会话夹具，返回管理器与按标题索引的会话 id。
    private func seeded() -> (
        conversations: DefaultConversationManager,
        messages: DefaultMessageManager,
        ids: [String: UUID]
    ) {
        let conversations = DefaultConversationManager()
        let messages = DefaultMessageManager()
        MessageListEmptyUITestingSupport.seed(
            conversations: conversations,
            messages: messages
        )
        var ids: [String: UUID] = [:]
        for conversation in conversations.conversations {
            if let title = conversation.title { ids[title] = conversation.id }
        }
        return (conversations, messages, ids)
    }

    private func windowStart() -> Date {
        let calendar = Calendar.current
        return calendar.date(
            byAdding: .day,
            value: -(EmptyStateActivityViewModel.windowDayCount - 1),
            to: calendar.startOfDay(for: .now)
        ) ?? Date()
    }

    @Test("seeds exactly the three conversations the UI tests depend on")
    func fixtureSeedsAllThreeConversations() {
        let (conversations, _, ids) = seeded()
        let titles = conversations.conversations.compactMap(\.title)

        #expect(ids[MessageListEmptyUITestingSupport.emptyConversationTitle] != nil,
                "空会话未种出，实际种出：\(titles)")
        #expect(ids[MessageListEmptyUITestingSupport.historyConversationTitle] != nil,
                "历史会话未种出，实际种出：\(titles)")
        #expect(ids[MessageListEmptyUITestingSupport.toolOnlyConversationTitle] != nil,
                "仅 tool 消息的会话未种出，实际种出：\(titles)")
        #expect(conversations.conversations.count == 3,
                "夹具应恰好种出 3 个会话，实际 \(conversations.conversations.count)：\(titles)")
    }

    /// 起始态必须是空会话：UI 测试的所有空态用例都以此为前提。
    @Test("selects the empty conversation as the starting state")
    func fixtureSelectsEmptyConversation() throws {
        let (conversations, _, ids) = seeded()

        let emptyID = try #require(ids[MessageListEmptyUITestingSupport.emptyConversationTitle])
        #expect(conversations.selectedConversationID == emptyID,
                "应默认选中空会话，实际选中：\(conversations.selectedConversationID?.uuidString ?? "nil")")
    }

    /// 空会话必须真的一条消息都没有。
    ///
    /// 若它意外带了消息，空态永远不会出现，而 UI 测试会以为「产品没渲染空态」。
    @Test("the empty conversation really has no messages")
    func fixtureEmptyConversationIsEmpty() throws {
        let (_, messages, ids) = seeded()

        let emptyID = try #require(ids[MessageListEmptyUITestingSupport.emptyConversationTitle])
        #expect(messages.messages(for: emptyID).isEmpty,
                "空会话不应有消息，实际 \(messages.messages(for: emptyID).count) 条")
        // 端到端意义上也必须是空的：这正是插件判定用的那个接口。
        #expect(messages.messagePage(
            for: emptyID, limit: 1, beforeMessageID: nil, includesToolMessages: false
        ).isEmpty)
    }

    /// 历史会话必须带可见消息，否则活动条会因 `hasActivity == false` 而不渲染，
    /// 「空态 + 活动条」这条最关键路径就测不到了。
    @Test("the history conversation has the messages the activity strip counts")
    func fixtureHistoryConversationHasMessages() throws {
        let (_, messages, ids) = seeded()

        let historyID = try #require(ids[MessageListEmptyUITestingSupport.historyConversationTitle])
        let seededMessages = messages.messages(for: historyID)
        #expect(seededMessages.count == Self.historyMessageCount,
                "历史会话应有 \(Self.historyMessageCount) 条消息，实际 \(seededMessages.count)")
        #expect(seededMessages.filter { $0.role == .user }.count == 4)
        #expect(seededMessages.filter { $0.role == .assistant }.count == 4)
    }

    /// 钉住底部活动条的统计口径。
    ///
    /// - Important: 这里是 **9** 而不是历史会话的 8 条。`dailyMessageCounts`
    ///   按设计统计**所有会话的所有角色**，因此 tool-only 会话里那 1 条 tool
    ///   消息同样计入。这与空态判定（`includesToolMessages: false`）是两条
    ///   独立路径，两者的差异是**刻意保留**的：
    ///   - 活动条回答「我最近干了多少活」→ 工具输出是干活产生的，计入合理；
    ///   - 空态判定回答「这个会话有没有用户看得到的对话」→ tool 消息不算。
    ///
    ///   后来的修改者若把这里「修正」成 8，等于让活动条漏掉工具产出，
    ///   是行为变更而非修正。因此这条用例同时充当口径的书面记录。
    @Test("activity counts include tool messages, unlike the empty-state check")
    func fixtureActivityCountsUseCrossConversationScope() {
        let (_, messages, _) = seeded()

        let counts = messages.dailyMessageCounts(since: windowStart())
        let total = counts.values.reduce(0, +)
        let expected = Self.historyMessageCount + Self.toolOnlyMessageCount
        #expect(total == expected,
                "30 天窗口内应统计到 \(expected) 条（8 条历史 + 1 条 tool），实际 \(total)：\(counts)")
        #expect(counts.filter { $0.value > 0 }.count == 5,
                "应落在 5 个不同日期上，实际 \(counts.count)：\(counts)")
    }

    /// token 统计同样要有值，否则趋势线不渲染，少覆盖一段 UI。
    ///
    /// tool 消息不带 token，因此这里仍是 4 天 ×（1200 + 800）。
    @Test("history messages carry tokens so the trend line has data")
    func fixtureHistoryCarriesTokens() {
        let (_, messages, _) = seeded()

        let total = messages.dailyTokenCounts(since: windowStart()).values.reduce(0, +)
        #expect(total == 8_000, "30 天窗口内应有 8000 token，实际 \(total)")
    }

    /// 仅 tool 消息的会话：工具消息不得算作「用户可见消息」。
    ///
    /// 这是「工具输出存在 → 空态仍应显示」这一产品行为的纯内存验证，
    /// 与上面那条统计口径用例互为对照。
    @Test("the tool-only conversation stays empty for the empty-state check")
    func fixtureToolOnlyConversationCountsAsEmpty() throws {
        let (_, messages, ids) = seeded()

        let toolOnlyID = try #require(ids[MessageListEmptyUITestingSupport.toolOnlyConversationTitle])
        #expect(messages.messages(for: toolOnlyID).count == Self.toolOnlyMessageCount,
                "夹具应写入 \(Self.toolOnlyMessageCount) 条 tool 消息")
        // 插件判定用的正是这个调用：不含 tool 消息，因此结果必须为空。
        #expect(
            messages.messagePage(
                for: toolOnlyID, limit: 1, beforeMessageID: nil, includesToolMessages: false
            ).isEmpty,
            "仅含 tool 消息的会话被判为非空，空态会凭空消失"
        )
    }

    /// 重复 seed 不得产生重复会话（幂等）。
    @Test("repeated seed does not duplicate conversations")
    func fixtureSeedIsIdempotent() {
        let conversations = DefaultConversationManager()
        let messages = DefaultMessageManager()

        MessageListEmptyUITestingSupport.seed(conversations: conversations, messages: messages)
        MessageListEmptyUITestingSupport.seed(conversations: conversations, messages: messages)

        #expect(
            conversations.conversations.count == 3,
            "重复 seed 后应仍为 3 个会话，实际 \(conversations.conversations.count)：\(conversations.conversations.compactMap(\.title))"
        )
    }

    /// 启动参数判定：只有带对应参数时才启用夹具。
    ///
    /// 这保证了普通 Debug 启动不会被夹具污染。
    @Test("the fixture only activates with its launch argument")
    func fixtureOnlyActivatesWithLaunchArgument() {
        #expect(
            MessageListEmptyUITestingSupport.isEnabled(arguments: []) == false,
            "没有启动参数时夹具必须关闭，否则会污染正常 Debug 会话"
        )
        #expect(
            MessageListEmptyUITestingSupport.isEnabled(
                arguments: ["--lumi-ui-testing-message-list-empty"]
            ),
            "带启动参数时夹具应启用"
        )
        #expect(
            MessageListEmptyUITestingSupport.isEnabled(
                arguments: ["--lumi-ui-testing-isolated-storage"]
            ) == false,
            "只有隔离存储参数时不应启用本夹具"
        )
    }
}
#endif
