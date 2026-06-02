import SwiftUI
import LumiCoreKit

/// 错误消息渲染器
public struct ErrorMessageRenderer: SuperMessageRenderer {
    public static let id = "error-message"
    public static let priority = 160

    public init() {}

    public func canRender(message: ChatMessage) -> Bool {
        message.role == .error || message.isError
    }

    @MainActor
    public func render(message: ChatMessage, showRawMessage: Binding<Bool>) -> AnyView {
        AnyView(ErrorMessage(message: message, showRawMessage: showRawMessage))
    }
}
