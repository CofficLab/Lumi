import SwiftUI

/// 错误消息渲染器
struct ErrorMessageRenderer: SuperMessageRenderer {
    static let id = "error-message"
    static let priority = 160

    func canRender(message: ChatMessage) -> Bool {
        message.role == .error || message.isError
    }

    @MainActor
    func render(message: ChatMessage, showRawMessage: Binding<Bool>) -> AnyView {
        AnyView(ErrorMessage(message: message, showRawMessage: showRawMessage))
    }
}
