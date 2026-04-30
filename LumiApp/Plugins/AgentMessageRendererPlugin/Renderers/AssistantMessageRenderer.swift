import SwiftUI

/// 助手消息渲染器
struct AssistantMessageRenderer: SuperMessageRenderer {
    static let id = "assistant-message"
    static let priority = 150

    func canRender(message: ChatMessage) -> Bool {
        message.role == .assistant
    }

    @MainActor
    func render(message: ChatMessage, showRawMessage: Binding<Bool>) -> AnyView {
        AnyView(
            AssistantMessage(
                message: message,
                isLastMessage: false,
                relatedToolOutputs: [],
                showRawMessage: showRawMessage
            )
        )
    }
}
