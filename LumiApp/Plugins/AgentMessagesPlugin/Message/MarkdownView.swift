import SwiftUI
import MarkdownUI

/// Markdown 消息视图，负责渲染聊天消息内容
/// 使用 MarkdownUI 库渲染（支持 GitHub Flavored Markdown）
struct MarkdownMessageView: View {
    let message: ChatMessage
    let showRawMessage: Bool

    var body: some View {
        Group {
            if showRawMessage {
                TextEditor(text: .constant(message.content))
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .scrollContentBackground(.hidden)
            } else {
                Markdown(message.content)
                    .textSelection(.enabled)
            }
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        MarkdownMessageView(
            message: ChatMessage(role: .assistant, content: """
                ## Try MarkdownUI
                
                **MarkdownUI** is a native Markdown renderer for SwiftUI
                compatible with the [GitHub Flavored Markdown Spec](https://github.github.com/gfm/).
                
                ### Code Example
                
                ```swift
                let hello = "world"
                print(hello)
                ```
                
                - List item 1
                - List item 2
                """),
            showRawMessage: false
        )

        MarkdownMessageView(
            message: ChatMessage(role: .assistant, content: "# Hello\nThis is a *markdown* message."),
            showRawMessage: true
        )
    }
    .padding()
}
