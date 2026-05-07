import SwiftUI

/// 状态消息渲染器
struct StatusMessageRenderer: SuperMessageRenderer {
    static let id = "status-message"
    static let priority = 150

    func canRender(message: ChatMessage) -> Bool {
        message.role == .status && message.content != ChatMessage.turnCompletedSystemContentKey
    }

    @MainActor
    func render(message: ChatMessage, showRawMessage: Binding<Bool>) -> AnyView {
        AnyView(StatusMessage(message: message))
    }
}
