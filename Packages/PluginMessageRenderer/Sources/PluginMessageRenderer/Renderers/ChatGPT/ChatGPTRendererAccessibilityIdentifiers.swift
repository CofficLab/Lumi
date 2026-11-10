import Foundation

/// V5（ChatGPT）渲染层的无障碍标识符。
///
/// - Important: 这些标识符是 UI 测试的**唯一**定位锚点。
///   改动会让既有的 XCUITest 与截图矩阵失效，因此与视觉规格一样视为契约。
///
/// - Note: 列表层（`PluginMessageListChatGPT`）另有一份同名前缀的清单。
///   两个包互不依赖（插件不得依赖插件），因此不能共用同一个常量。
enum ChatGPTRendererAccessibilityIdentifiers {
    /// 用户气泡。
    static let userBubble = "lumi.message.chatgpt.user-bubble"
    /// 用户气泡的正文。
    static let userBubbleBody = "lumi.message.chatgpt.user-bubble-body"
    /// 用户气泡的复制按钮。
    static let userCopyButton = "lumi.message.chatgpt.user-copy"
    /// 用户消息的再次发送按钮。
    static let userResendButton = "lumi.message.chatgpt.user-resend"

    /// 助手正文。
    static let assistantBody = "lumi.message.chatgpt.assistant-body"
    /// 轮尾操作栏。
    static let turnActionBar = "lumi.message.chatgpt.turn-action-bar"
    /// 轮尾复制按钮。
    static let turnCopyButton = "lumi.message.chatgpt.turn-copy"

    /// reasoning 折叠块。
    static let reasoningBlock = "lumi.message.chatgpt.reasoning"
    /// reasoning 展开 / 收起按钮。
    static let reasoningToggle = "lumi.message.chatgpt.reasoning-toggle"

    /// 工作工具历史分组。
    static let workHistory = "lumi.message.chatgpt.work-history"
    /// 工作工具历史展开 / 收起按钮。
    static let workHistoryToggle = "lumi.message.chatgpt.work-history-toggle"

    /// timeline marker。
    static let timelineMarker = "lumi.message.chatgpt.timeline-marker"

    /// 内联错误正文。
    static let errorContent = "lumi.message.chatgpt.error-content"
    /// 内联错误的重试按钮。
    static let errorRetryButton = "lumi.message.chatgpt.error-retry"
}
