import SwiftUI
import LumiCoreKit

/// 状态消息渲染器
public struct StatusMessageRenderer: SuperMessageRenderer {
    public static let id = "status-message"
    public static let priority = 150

    public init() {}

    public func canRender(message: ChatMessage) -> Bool {
        message.role == .status && message.content != ChatMessage.turnCompletedSystemContentKey
    }

    @MainActor
    public func render(message: ChatMessage, showRawMessage: Binding<Bool>) -> AnyView {
        AnyView(StatusMessage(message: message))
    }
}
