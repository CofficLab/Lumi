import SwiftUI
import LumiCoreKit

/// 默认 Markdown 渲染器（兜底）
public struct DefaultMarkdownRenderer: SuperMessageRenderer {
    public static let id = "default-markdown"
    public static let priority = 0

    public init() {}

    public func canRender(message: ChatMessage) -> Bool {
        true
    }

    @MainActor
    public func render(message: ChatMessage, showRawMessage: Binding<Bool>) -> AnyView {
        AnyView(
            MarkdownView(message: message, showRawMessage: showRawMessage.wrappedValue)
                .messageBubbleStyle(role: message.role, isError: message.isError)
        )
    }
}
