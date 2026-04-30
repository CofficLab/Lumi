import SwiftUI

/// 用户消息渲染器
struct UserMessageRenderer: SuperMessageRenderer {
    static let id = "user-message"
    static let priority = 150

    func canRender(message: ChatMessage) -> Bool {
        message.role == .user
    }

    @MainActor
    func render(message: ChatMessage, showRawMessage: Binding<Bool>) -> AnyView {
        AnyView(UserMessage(message: message, showRawMessage: showRawMessage))
    }
}
