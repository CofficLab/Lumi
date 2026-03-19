import MagicKit
import SwiftUI

// MARK: - Status Message
//
/// 负责渲染状态类消息（如“等待响应…”、“生成中…”），统一样式
struct StatusMessage: View {
    let message: ChatMessage

    var body: some View {
        PlainTextMessageContentView(
            content: message.content,
            monospaced: false
        )
        .font(DesignTokens.Typography.caption1)
        .messageBubbleStyle(role: message.role, isError: message.isError)
    }
}
