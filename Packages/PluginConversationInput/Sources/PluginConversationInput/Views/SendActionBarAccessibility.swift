import Foundation

/// Action Bar 发送/停止按钮的无障碍标识符。
///
/// UI 测试（`LumiSendActionBarUITests`）按标识符定位控件，而不是按本地化文案：
/// AX label 会随 `-AppleLanguages` 变化，按文案定位在非英文环境下必然失败。
///
/// 命名沿用仓库既有惯例（见 `RetryTurnButton.accessibilityIdentifier`），
/// 前缀为 `lumi.conversation-input.` 与插件 id 保持一致。
enum SendActionBarAccessibility {
    /// 发送按钮。发送中时该按钮不存在，停止按钮顶替其位置。
    static let sendButton = "lumi.conversation-input.send"

    /// 停止按钮。仅在当前会话有回合运行时存在。
    static let stopButton = "lumi.conversation-input.stop"

    /// Provider 缺失时的错误按钮。点击后弹出缺失列表。
    static let errorButton = "lumi.conversation-input.action-bar.error"
}
