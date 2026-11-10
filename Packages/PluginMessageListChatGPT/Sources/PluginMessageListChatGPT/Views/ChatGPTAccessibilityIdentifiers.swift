import Foundation

/// V5（ChatGPT）列表层的无障碍标识符。
///
/// - Important: 这些标识符是 UI 测试的**唯一**定位锚点。
///   改动会让既有的 XCUITest 与截图矩阵失效，因此与视觉规格一样视为契约。
///
/// - Note: 渲染层（`PluginMessageRenderer`）另有一份同名前缀的清单。
///   两个包互不依赖（插件不得依赖插件），因此不能共用同一个常量。
enum ChatGPTAccessibilityIdentifiers {
    /// 列表容器。
    static let listContainer = "lumi.message-list.chatgpt.container"
    /// 「加载更早的消息」按钮。
    static let loadEarlierButton = "lumi.message-list.chatgpt.load-earlier"
    /// 「回到底部」按钮。
    static let backToBottomButton = "lumi.message-list.chatgpt.back-to-bottom"
    /// 单个轮次。
    static let turn = "lumi.message-list.chatgpt.turn"
}
