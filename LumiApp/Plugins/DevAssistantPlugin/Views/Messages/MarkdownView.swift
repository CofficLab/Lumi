import SwiftUI
import Textual

/// Markdown 消息视图，负责渲染聊天消息内容
struct MarkdownMessageView: View {
    let message: ChatMessage
    let showRawMessage: Bool

    var body: some View {
        Group {
            if showRawMessage {
                Text(message.content)
                    .textSelection(.enabled)
            } else {
                // 使用 Textual 渲染 Markdown 内容
                if message.role == .user {
                    // 用户消息：使用 InlineText
                    InlineText(markdown: message.content)
                        .textSelection(.enabled)
                } else {
                    // 助手消息：使用 StructuredText 支持完整 Markdown
                    StructuredText(markdown: message.content)
                        .textual.structuredTextStyle(.default)
                        .textual.textSelection(.enabled)
                }
            }
        }
    }
}

#Preview {
    VStack {
        MarkdownMessageView(
            message: ChatMessage(role: .assistant, content: "# Hello\nThis is a *markdown* message."),
            showRawMessage: false
        )

        MarkdownMessageView(
            message: ChatMessage(role: .assistant, content: "# Hello\nThis is a *markdown* message."),
            showRawMessage: true
        )
    }
    .padding()
}