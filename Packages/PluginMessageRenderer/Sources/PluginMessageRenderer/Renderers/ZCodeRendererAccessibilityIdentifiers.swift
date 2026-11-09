import Foundation

/// V4（ZCode）渲染层的无障碍标识符。
///
/// - Important: 这些标识符是 UI 测试的**唯一**定位锚点。
///   改动会让既有的 XCUITest 与截图矩阵失效，因此与视觉规格一样视为契约。
///
/// - Note: 列表层（`PluginMessageListDetailed`）另有一份同名前缀的清单。
///   两个包互不依赖（插件不得依赖插件），因此不能共用同一个常量。
enum ZCodeRendererAccessibilityIdentifiers {
    /// 用户气泡。
    static let userBubble = "lumi.message.zcode.user-bubble"
    /// 用户气泡的正文。
    static let userBubbleBody = "lumi.message.zcode.user-bubble-body"
    /// 用户气泡的复制按钮。
    static let userCopyButton = "lumi.message.zcode.user-copy"
    /// 长文展开 / 收起按钮。
    static let userExpandToggle = "lumi.message.zcode.user-expand-toggle"

    /// 助手正文。
    static let assistantBody = "lumi.message.zcode.assistant-body"
    /// 轮尾操作栏。
    static let turnActionBar = "lumi.message.zcode.turn-action-bar"
    /// 轮尾复制按钮。
    static let turnCopyButton = "lumi.message.zcode.turn-copy"
    /// 轮尾时间标签。
    static let turnTimeLabel = "lumi.message.zcode.turn-time"

    /// reasoning 折叠块。
    static let reasoningBlock = "lumi.message.zcode.reasoning"
    /// reasoning 展开 / 收起按钮。
    static let reasoningToggle = "lumi.message.zcode.reasoning-toggle"

    /// 工作工具历史分组。
    static let workHistory = "lumi.message.zcode.work-history"
    /// 工作工具历史展开 / 收起按钮。
    static let workHistoryToggle = "lumi.message.zcode.work-history-toggle"

    /// timeline marker。
    static let timelineMarker = "lumi.message.zcode.timeline-marker"
}
