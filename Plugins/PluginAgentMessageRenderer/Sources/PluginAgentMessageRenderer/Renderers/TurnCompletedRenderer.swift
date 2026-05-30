import SwiftUI
import LumiCoreKit

/// 对话轮次结束分隔线渲染器
public struct TurnCompletedRenderer: SuperMessageRenderer {
    public static let id = "turn-completed"
    public static let priority = 200

    public init() {}

    public func canRender(message: ChatMessage) -> Bool {
        message.content == ChatMessage.turnCompletedSystemContentKey
    }

    @MainActor
    public func render(message: ChatMessage, showRawMessage: Binding<Bool>) -> AnyView {
        AnyView(TurnCompletedDivider(message: message))
    }
}
