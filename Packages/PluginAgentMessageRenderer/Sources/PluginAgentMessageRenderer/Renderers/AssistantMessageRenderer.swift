import SwiftUI
import LumiCoreKit

/// 助手消息渲染器
public struct AssistantMessageRenderer: SuperMessageRenderer {
    public static let id = "assistant-message"
    public static let priority = 150

    public init() {}

    public func canRender(message: ChatMessage) -> Bool {
        message.role == .assistant
    }

    @MainActor
    public func render(message: ChatMessage, showRawMessage: Binding<Bool>) -> AnyView {
        AnyView(
            AssistantMessage(
                message: message,
                isLastMessage: false,
                showRawMessage: showRawMessage
            )
        )
    }
}
