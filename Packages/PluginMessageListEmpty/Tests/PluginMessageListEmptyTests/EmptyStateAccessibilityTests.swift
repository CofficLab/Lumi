import Testing
@testable import PluginMessageListEmpty

/// 空态可访问性标识符的契约。
///
/// ## 为什么这层值得单独锁住
///
/// 标识符是 UI 测试与实现之间的**唯一契约**。一旦 View 侧改了字符串而
/// 常量没改（或反之），UI 测试会在「元素找不到」上失败 —— 但这个失败
/// 与产品行为无关，排查成本高。反过来，若有人误以为标识符无用而删掉，
/// 没有这层测试就只能等 UI 测试红才发现。
///
/// 同时锁定**两个**标识符的区分性：它们分别对应「未选中对话」与
/// 「当前会话无消息」两种完全不同的用户处境。一旦有人图省事让两者
/// 复用同一个 id，这层测试会立刻失败 —— 那会让 UI 测试无法分辨真实
/// 渲染的是哪种空态，掩盖掉一整类接缝缺陷。
@Test func emptyStateAccessibilityIdentifiersAreStableAndDistinct() {
    #expect(
        MessageListEmptyAccessibility.noConversationSelectedID
            == "lumi.message-list.empty.no-conversation-selected"
    )
    #expect(
        MessageListEmptyAccessibility.noMessagesID
            == "lumi.message-list.empty.no-messages"
    )
    #expect(
        MessageListEmptyAccessibility.defaultTitleLabel == "How can I help you today?"
    )
    #expect(
        MessageListEmptyAccessibility.activityStripID == "lumi.message-list.empty.activity"
    )
    #expect(
        MessageListEmptyAccessibility.activityCardID == "lumi.message-list.empty.activity-card"
    )
    #expect(
        MessageListEmptyAccessibility.activityAnchorID == "lumi.message-list.empty.activity-anchor"
    )

    // 两种空态必须能被分别定位。
    #expect(
        MessageListEmptyAccessibility.noConversationSelectedID
            != MessageListEmptyAccessibility.noMessagesID,
        "「未选中对话」与「当前会话无消息」必须使用不同标识符，否则 UI 测试无法分辨渲染的是哪种空态"
    )

    // 活动条、活动卡、锚点文案也必须能被分别定位：合卡之后 UI 测试要能
    // 区分「条出现了」「卡出现了」「数字还在」这三件事。
    #expect(
        Set([
            MessageListEmptyAccessibility.activityStripID,
            MessageListEmptyAccessibility.activityCardID,
            MessageListEmptyAccessibility.activityAnchorID,
        ]).count == 3,
        "活动条 / 活动卡 / 锚点文案必须使用互不相同的标识符"
    )

    // 与既有标识符不冲突，避免嵌套时空态抢走对话列表的行标识。
    #expect(
        !MessageListEmptyAccessibility.noConversationSelectedID.contains("conversation-list")
    )
    #expect(!MessageListEmptyAccessibility.noMessagesID.contains("conversation-list"))
}
