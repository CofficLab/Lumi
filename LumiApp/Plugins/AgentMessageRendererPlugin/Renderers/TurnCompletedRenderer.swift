import SwiftUI

/// 对话轮次结束分隔线渲染器
struct TurnCompletedRenderer: SuperMessageRenderer {
    static let id = "turn-completed"
    static let priority = 200

    func canRender(message: ChatMessage) -> Bool {
        message.content == ChatMessage.turnCompletedSystemContentKey
    }

    @MainActor
    func render(message: ChatMessage, showRawMessage: Binding<Bool>) -> AnyView {
        AnyView(TurnCompletedDivider(message: message))
    }
}
