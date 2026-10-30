#if DEBUG
import Foundation
import ProviderConversation
import ProviderMessage
import Testing
@testable import PluginMessageListStandard

/// UI 测试夹具的 seed 行为验证（不启动 App）。
///
/// ## 为什么需要这一层
///
/// 夹具 `MessageListStandardUITestingSupport` 的产物是 UI 测试的**唯一**数据源。
/// 一旦它没种出预期的会话，UI 层只会报一句
/// 「会话「Switch Target Small」在列表中不可见」——指向定位失败，
/// 而真实原因是**数据根本没种出来**。两层混在一起时，归因必然出错。
///
/// 因此这里在纯内存层面直接断言 seed 的产物，把「数据问题」与
/// 「可访问性/定位问题」彻底分开。
///
/// - Important: 夹具 `MessageListStandardUITestingSupport` 整体位于
///   `#if DEBUG`，因此**整个文件**（含 import）同样包裹。少了这个守卫，
///   `swift build -c release` 会因找不到该类型而失败 —— 本地 Debug 通过
///   完全掩盖不了这一点。
@MainActor
@Test("夹具：seed 后四个会话都存在，且都带消息")
func fixtureSeedsBothConversations() {
    let conversations = DefaultConversationManager()
    let messages = DefaultMessageManager()

    MessageListStandardUITestingSupport.seed(
        conversations: conversations,
        messages: messages
    )

    let titles = conversations.conversations.compactMap(\.title)
    #expect(
        titles.contains(MessageListStandardUITestingSupport.smallConversationTitle),
        "小会话未种出，实际种出：\(titles)"
    )
    #expect(
        titles.contains(MessageListStandardUITestingSupport.largeConversationTitle),
        "大会话未种出，实际种出：\(titles)"
    )
    #expect(
        titles.contains(MessageListStandardUITestingSupport.hugeConversationTitle),
        "超大会话未种出，实际种出：\(titles)"
    )
    #expect(
        titles.contains(MessageListStandardUITestingSupport.toolGroupConversationTitle),
        "工具调用组会话未种出，实际种出：\(titles)"
    )
    #expect(titles.count == 4, "夹具应恰好种出 4 个会话，实际 \(titles.count)：\(titles)")
}

/// 四个会话都必须有消息，否则切换过去是空列表，无法覆盖遮罩收敛路径。
@MainActor
@Test("夹具：四个会话都写入了消息")
func fixtureSeedsMessagesForBothConversations() {
    let conversations = DefaultConversationManager()
    let messages = DefaultMessageManager()

    MessageListStandardUITestingSupport.seed(
        conversations: conversations,
        messages: messages
    )

    for title in [
        MessageListStandardUITestingSupport.smallConversationTitle,
        MessageListStandardUITestingSupport.largeConversationTitle,
        MessageListStandardUITestingSupport.hugeConversationTitle,
        MessageListStandardUITestingSupport.toolGroupConversationTitle
    ] {
        let conversation = conversations.conversations.first { $0.title == title }
        #expect(conversation != nil, "会话「\(title)」不存在")
        guard let conversation else { continue }
        let seeded = messages.messages(for: conversation.id)
        #expect(!seeded.isEmpty, "会话「\(title)」没有消息")
    }
}

/// 超大会话必须**远超窗口上限**，否则「窗口裁剪」路径根本不会被触发。
///
/// `maxRetainedCount` = 300，而分页窗口 = 40。要让「翻页 → 裁剪 → 缺口」
/// 这条链路在 UI 层可复现，消息数必须显著大于 300。
@MainActor
@Test("夹具：超大会话消息数远超窗口上限")
func fixtureHugeConversationExceedsWindowLimit() {
    let conversations = DefaultConversationManager()
    let messages = DefaultMessageManager()

    MessageListStandardUITestingSupport.seed(
        conversations: conversations,
        messages: messages
    )

    guard let id = conversations.conversations
        .first(where: { $0.title == MessageListStandardUITestingSupport.hugeConversationTitle })?
        .id
    else {
        Issue.record("超大会话未种出")
        return
    }
    let count = messages.messages(for: id).count
    #expect(
        count > 300,
        "超大会话应远超窗口上限 300，实际 \(count) 条"
    )
}

/// 大会话必须是「更难收敛」的一侧——它是首屏遮罩的主要施压对象。
///
/// 若两个会话体量相同，这条用例就失去了区分度，遮罩测试会退化成
/// 只覆盖简单场景。
@MainActor
@Test("夹具：大会话消息数显著多于小会话")
func fixtureLargeConversationIsHarder() {
    let conversations = DefaultConversationManager()
    let messages = DefaultMessageManager()

    MessageListStandardUITestingSupport.seed(
        conversations: conversations,
        messages: messages
    )

    func count(_ title: String) -> Int {
        guard let id = conversations.conversations.first(where: { $0.title == title })?.id else {
            return 0
        }
        return messages.messages(for: id).count
    }

    let small = count(MessageListStandardUITestingSupport.smallConversationTitle)
    let large = count(MessageListStandardUITestingSupport.largeConversationTitle)
    #expect(small > 0 && large > 0, "两个会话都应有消息，small=\(small) large=\(large)")
    #expect(
        large > small * 2,
        "大会话应显著更大（几何持续增长才逼近收敛上限），small=\(small) large=\(large)"
    )
}

/// 默认选中大会话：它是更难收敛的一侧，作为 UI 测试的起始态。
@MainActor
@Test("夹具：默认选中大会话且为 standard 详细程度")
func fixtureSelectsLargeConversation() {
    let conversations = DefaultConversationManager()
    let messages = DefaultMessageManager()

    MessageListStandardUITestingSupport.seed(
        conversations: conversations,
        messages: messages
    )

    let selected = conversations.selectedConversationID
    let selectedTitle = selected.flatMap { id in
        conversations.conversations.first { $0.id == id }?.title
    }
    #expect(
        selectedTitle == MessageListStandardUITestingSupport.largeConversationTitle,
        "应默认选中大会话，实际选中：\(selectedTitle ?? "nil")"
    )
    if let selected {
        #expect(
            conversations.verbosity(for: selected) == .standard,
            "大会话应为 standard 详细程度，否则 V2 列表槽位不会激活"
        )
    }
}

/// 重复 seed 不得产生重复会话（幂等）。
@MainActor
@Test("夹具：重复 seed 不产生重复会话")
func fixtureSeedIsIdempotent() {
    let conversations = DefaultConversationManager()
    let messages = DefaultMessageManager()

    MessageListStandardUITestingSupport.seed(conversations: conversations, messages: messages)
    MessageListStandardUITestingSupport.seed(conversations: conversations, messages: messages)

    #expect(
        conversations.conversations.count == 4,
        "重复 seed 后应仍为 4 个会话，实际 \(conversations.conversations.count)：\(conversations.conversations.compactMap(\.title))"
    )
}

#endif
