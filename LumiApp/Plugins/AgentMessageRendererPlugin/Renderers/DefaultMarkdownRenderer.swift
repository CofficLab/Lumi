import SwiftUI

/// 默认 Markdown 渲染器（兜底）
struct DefaultMarkdownRenderer: SuperMessageRenderer {
    static let id = "default-markdown"
    static let priority = 0

    func canRender(message: ChatMessage) -> Bool {
        true
    }

    @MainActor
    func render(message: ChatMessage, showRawMessage: Binding<Bool>) -> AnyView {
        AnyView(
            MarkdownView(message: message, showRawMessage: showRawMessage.wrappedValue)
                .messageBubbleStyle(role: message.role, isError: message.isError)
        )
    }
}
