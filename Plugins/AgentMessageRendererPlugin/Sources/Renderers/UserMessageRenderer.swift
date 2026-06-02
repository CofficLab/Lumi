import SwiftUI
import LumiCoreKit

/// 用户消息渲染器
public struct UserMessageRenderer: SuperMessageRenderer {
    public static let id = "user-message"
    public static let priority = 150

    public init() {}

    public func canRender(message: ChatMessage) -> Bool {
        message.role == .user
    }

    @MainActor
    public func render(message: ChatMessage, showRawMessage: Binding<Bool>) -> AnyView {
        AnyView(UserMessage(message: message, showRawMessage: showRawMessage))
    }
}
