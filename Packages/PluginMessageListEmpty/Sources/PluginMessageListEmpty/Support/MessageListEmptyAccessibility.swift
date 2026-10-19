import Foundation

/// 消息列表空态的可访问性标识符。
///
/// ## 为什么需要集中在这里
///
/// 空态此前**没有任何** accessibility 修饰，后果与当初的对话列表同源：
/// 1. 屏幕阅读器读不到「当前没有选中对话」这一状态 —— 用户无从得知为什么
///    聊天区是空的、该往哪里输入；
/// 2. UI 测试无法按标识符定位空态，因此「全新安装首屏展示空态」这条
///    用户旅程无法端到端验证，只能靠间接推断（后端状态对不对）。
///
/// 放在独立文件而非 View 内，是为了让 UI 测试 target（不依赖插件模块）
/// 引用同一份常量，避免测试里硬编码字符串后与实现悄悄脱钩 —— 这一点
/// 与 `ConversationListAccessibility` 的做法一致。
public enum MessageListEmptyAccessibility {
    /// 「未选中任何对话」的空态容器（`NoConversationSelectedView`）。
    ///
    /// - Note: 这是全新安装首屏的判据标识。选中会话但无消息时渲染的是
    ///   `MessageEmptyStateView`，用 `noMessagesID` 区分 —— 两者都是
    ///   「空态」，但对应完全不同的用户处境与触发路径，必须能被分别断言。
    public static let noConversationSelectedID = "lumi.message-list.empty.no-conversation-selected"

    /// 「当前会话没有消息」的空态容器（`MessageEmptyStateView`）。
    public static let noMessagesID = "lumi.message-list.empty.no-messages"

    /// 空态主标题。用于断言「空态确实渲染出了预期的引导文案」，
    /// 而不仅仅是「某个容器存在」。
    ///
    /// - Important: 默认文案随语言变化，因此**仅在以 `-AppleLanguages (en)`
    ///   启动的 UI 测试中断言**。定位不到时应优先怀疑语言参数没生效。
    public static let defaultTitleLabel = "How can I help you today?"

    /// 底部活动条（30 天热力图 + 摘要 + token 趋势）。
    ///
    /// 它是独立的 `bottomFixed` 槽位，不与空态容器嵌套，因此需要自己的标识符：
    /// 断言「空态出现」不会顺带证明「活动条出现」。
    public static let activityStripID = "lumi.message-list.empty.activity"

    /// 建议 chip 的流式容器。
    public static let suggestionFlowID = "lumi.message-list.empty.suggestion-flow"

    /// 单个建议 chip，后缀为 suggestion id。
    ///
    /// 带 id 后缀是为了让测试能点名具体 chip，而不是「点第一个」——
    /// 后者会依赖 Provider 的返回顺序，夹具微调就可能点到另一条。
    public static func suggestionChipID(id: String) -> String {
        "lumi.message-list.empty.suggestion.\(id)"
    }
}
