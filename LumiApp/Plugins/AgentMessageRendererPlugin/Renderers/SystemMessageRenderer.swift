import SwiftUI

/// 系统消息渲染器
struct SystemMessageRenderer: SuperMessageRenderer {
    static let id = "system-message"
    static let priority = 150

    func canRender(message: ChatMessage) -> Bool {
        message.role == .system && !message.isToolOutput
            && message.content != ChatMessage.loadingLocalModelSystemContentKey
            && message.content != ChatMessage.loadingLocalModelDoneSystemContentKey
    }

    @MainActor
    func render(message: ChatMessage, showRawMessage: Binding<Bool>) -> AnyView {
        AnyView(SystemMessage(message: message, showRawMessage: showRawMessage))
    }
}
