import SwiftUI
import LumiCoreKit

/// 系统消息渲染器
public struct SystemMessageRenderer: SuperMessageRenderer {
    public static let id = "system-message"
    public static let priority = 150

    public init() {}

    public func canRender(message: ChatMessage) -> Bool {
        message.role == .system && !message.isToolOutput
            && message.content != ChatMessage.loadingLocalModelSystemContentKey
            && message.content != ChatMessage.loadingLocalModelDoneSystemContentKey
    }

    @MainActor
    public func render(message: ChatMessage, showRawMessage: Binding<Bool>) -> AnyView {
        AnyView(SystemMessage(message: message, showRawMessage: showRawMessage))
    }
}
