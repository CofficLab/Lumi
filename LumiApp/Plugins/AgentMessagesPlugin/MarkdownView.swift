import SwiftUI
import Textual

/// Markdown 消息视图，负责渲染聊天消息内容
struct MarkdownMessageView: View {
    let message: ChatMessage
    let showRawMessage: Bool

    @State private var isTextualReady = false

    /// 检查是否是欢迎消息（包含特定标记）
    private var isWelcomeMessage: Bool {
        message.content.contains("你好！我是你的智能编程助手")
    }

    var body: some View {
        Group {
            if showRawMessage {
                Text(message.content)
                    .textSelection(.enabled)
            } else if isWelcomeMessage {
                Text(message.content)
                    .textSelection(.enabled)
            } else if isTextualReady {
                if message.role == .user {
                    InlineText(markdown: message.content)
                        .textual.textSelection(.enabled)
                } else {
                    StructuredText(markdown: message.content)
                        .textual.structuredTextStyle(.default)
                        .textual.textSelection(.enabled)
                }
            } else {
                Text(message.content)
                    .textSelection(.enabled)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isTextualReady = true
                        }
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
