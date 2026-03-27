import MagicKit
import SwiftUI

// MARK: - Status Message
//
/// 负责渲染状态类消息（如"等待响应…"、"生成中…"），统一样式
struct StatusMessage: View {
    let message: ChatMessage

    var body: some View {
        if message.content == ChatMessage.turnCompletedSystemContentKey {
            // 对话轮次结束的专用视图
            TurnCompletedDivider(message: message)
        } else {
            PlainTextMessageContentView(
                content: message.content,
                monospaced: false
            )
            .font(DesignTokens.Typography.caption1)
            .messageBubbleStyle(role: message.role, isError: message.isError)
        }
    }
}