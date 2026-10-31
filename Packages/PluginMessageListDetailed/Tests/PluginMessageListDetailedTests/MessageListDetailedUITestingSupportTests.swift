#if DEBUG
import Foundation
import ProviderConversation
import ProviderMessage
import Testing
@testable import PluginMessageListDetailed

/// UI 测试夹具的 seed 行为验证（不启动 App）。
///
/// ## 为什么需要这一层
///
/// 夹具 `MessageListDetailedUITestingSupport` 的产物是 UI 测试的**唯一**数据源。
/// 一旦它没种出预期的会话，UI 层只会报一句
/// 「会话「Detailed Target Large」在列表中不可见」——指向定位失败，
/// 而真实原因是**数据根本没种出来**。两层混在一起时，归因必然出错。
///
/// 因此这里在纯内存层面直接断言 seed 的产物，把「数据问题」与
/// 「可访问性/定位问题」彻底分开。
///
/// - Important: 夹具 `MessageListDetailedUITestingSupport` 整体位于
///   `#if DEBUG`，因此**整个文件**（含 import）同样包裹。少了这个守卫，
///   `swift build -c release` 会因找不到该类型而失败 —— 本地 Debug 通过
///   完全掩盖不了这一点。
@MainActor
@Test("夹具：seed 后三个会话都存在，且都带消息")
func fixtureSeedsAllConversations() {
    let conversations = DefaultConversationManager()
    let messages = DefaultMessageManager()

    MessageListDetailedUITestingSupport.seed(
        conversations: conversations,
        messages: messages
    )

    let titles = conversations.conversations.compactMap(\.title)
    #expect(
        titles.contains(MessageListDetailedUITestingSupport.smallConversationTitle),
        "小会话未种出，实际种出：\(titles)"
    )
    #expect(
        titles.contains(MessageListDetailedUITestingSupport.largeConversationTitle),
        "大会话未种出，实际种出：\(titles)"
    )
    #expect(
        titles.contains(MessageListDetailedUITestingSupport.toolGroupConversationTitle),
        "工具调用组会话未种出，实际种出：\(titles)"
    )
    #expect(titles.count == 3, "夹具应恰好种出 3 个会话，实际 \(titles.count)：\(titles)")
}

/// 三个会话都必须有消息，否则切换过去是空列表，无法覆盖遮罩收敛路径。
@MainActor
@Test("夹具：三个会话都写入了消息")
func fixtureSeedsMessagesForAllConversations() {
    let conversations = DefaultConversationManager()
    let messages = DefaultMessageManager()

    MessageListDetailedUITestingSupport.seed(
        conversations: conversations,
        messages: messages
    )

    for title in [
        MessageListDetailedUITestingSupport.smallConversationTitle,
        MessageListDetailedUITestingSupport.largeConversationTitle,
        MessageListDetailedUITestingSupport.toolGroupConversationTitle
    ] {
        let conversation = conversations.conversations.first { $0.title == title }
        #expect(conversation != nil, "会话「\(title)」不存在")
        guard let conversation else { continue }
        let seeded = messages.messages(for: conversation.id)
        #expect(!seeded.isEmpty, "会话「\(title)」没有消息")
    }
}

/// 工具调用组会话必须是 `.detailed` 详细程度。
///
/// 这是「V3 保持逐条铺开」这条 UI 断言的**前提**：V3 列表槽位只在
/// 「当前会话详细程度为 `.detailed`」时激活。若级别不是 detailed，
/// UI 测试测到的其实是 V2，断言失去意义。
@MainActor
@Test("夹具：工具调用组会话为 detailed 详细程度")
func fixtureToolGroupUsesDetailedVerbosity() {
    let conversations = DefaultConversationManager()
    let messages = DefaultMessageManager()

    MessageListDetailedUITestingSupport.seed(
        conversations: conversations,
        messages: messages
    )

    guard let conversation = conversations.conversations
        .first(where: { $0.title == MessageListDetailedUITestingSupport.toolGroupConversationTitle })
    else {
        Issue.record("工具调用组会话未种出")
        return
    }
    #expect(
        conversations.verbosity(for: conversation.id) == .detailed,
        "工具调用组会话应为 detailed 详细程度，否则 V3 列表槽位不会激活"
    )
}

/// 工具调用组会话必须含**多条**工具调用，且其中一条的正文非空。
///
/// 两个条件各自对应一条行为链：
///
/// - **多条**：折叠判定的输入是「组内调用数 > 1」。只有一条时
///   任何级别都不折叠，对照就失去区分度。
/// - **正文非空**：V3 的这条消息**不能**命中 `isToolExecutionOnly`
///   （正文为空才会命中），因此它**不会**被数据层合并成 `turn-activity`
///   合成消息，工具调用就**内联**在这条助手消息里——正是 V3
///   「保持逐条铺开」的原有形态。
///
/// 若这条消息的正文变成空，V3 也会走合成消息路径，
/// 「V2 折叠 / V3 不折叠」的对照就不再成立。
@MainActor
@Test("夹具：工具调用组会话含多条工具调用，且助手正文非空")
func fixtureToolGroupHasMultipleCallsWithNonEmptyBody() {
    let conversations = DefaultConversationManager()
    let messages = DefaultMessageManager()

    MessageListDetailedUITestingSupport.seed(
        conversations: conversations,
        messages: messages
    )

    guard let conversation = conversations.conversations
        .first(where: { $0.title == MessageListDetailedUITestingSupport.toolGroupConversationTitle })
    else {
        Issue.record("工具调用组会话未种出")
        return
    }

    let toolCalls = messages.messages(for: conversation.id)
        .flatMap { $0.toolCalls ?? [] }
    #expect(
        toolCalls.count > 1,
        "工具调用组会话应含多条工具调用，实际 \(toolCalls.count) 条"
    )

    // 含多条工具调用且正文非空的助手消息。
    let groupMessages = messages.messages(for: conversation.id).filter { message in
        message.role == .assistant && (message.toolCalls?.count ?? 0) > 1
    }
    #expect(
        groupMessages.count == 1,
        "应恰好有一条含多条工具调用的助手消息，实际 \(groupMessages.count) 条"
    )
    guard let group = groupMessages.first else { return }
    #expect(
        !group.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
        """
        该助手消息的正文必须非空——正文为空会命中 `isToolExecutionOnly`，
        被数据层合并成 `turn-activity` 合成消息，V3 的「保持逐条铺开」就失效了。
        """
    )
}

/// 重复 seed 不得产生重复会话（幂等）。
@MainActor
@Test("夹具：重复 seed 不产生重复会话")
func fixtureSeedIsIdempotent() {
    let conversations = DefaultConversationManager()
    let messages = DefaultMessageManager()

    MessageListDetailedUITestingSupport.seed(conversations: conversations, messages: messages)
    MessageListDetailedUITestingSupport.seed(conversations: conversations, messages: messages)

    #expect(
        conversations.conversations.count == 3,
        "重复 seed 后应仍为 3 个会话，实际 \(conversations.conversations.count)：\(conversations.conversations.compactMap(\.title))"
    )
}

#endif
