import MagicKit
import OSLog
import SwiftUI

// MARK: - Status Message
//
/// 负责渲染状态类消息（如“等待响应…”、“生成中…”），统一样式
struct StatusMessage: View, SuperLog {
    nonisolated static let emoji = "⌛️"
    nonisolated static let verbose = false

    let message: ChatMessage
    @Binding var showRawMessage: Bool

    var body: some View {
        MarkdownView(
            message: message,
            showRawMessage: showRawMessage,
            isCollapsible: false,
            isExpanded: true,
            onToggleExpand: {}
        )
        .font(DesignTokens.Typography.caption1)
        .messageBubbleStyle(role: message.role, isError: message.isError)
    }
}

