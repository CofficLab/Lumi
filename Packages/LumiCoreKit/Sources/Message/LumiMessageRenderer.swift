import SwiftUI

public struct LumiMessageRendererItem: Identifiable, @unchecked Sendable {
    public let id: String
    public let order: Int
    public let canRender: @MainActor (LumiChatMessage) -> Bool
    public let render: @MainActor (LumiChatMessage, Binding<Bool>) -> AnyView

    public init<Content: View>(
        id: String,
        order: Int = 0,
        canRender: @escaping @MainActor (LumiChatMessage) -> Bool,
        @ViewBuilder render: @escaping @MainActor (LumiChatMessage, Binding<Bool>) -> Content
    ) {
        self.id = id
        self.order = order
        self.canRender = canRender
        self.render = { AnyView(render($0, $1)) }
    }

    public init<Content: View>(
        id: String,
        order: Int = 0,
        canRender: @escaping @MainActor (LumiChatMessage) -> Bool,
        @ViewBuilder render: @escaping @MainActor (LumiChatMessage) -> Content
    ) {
        self.id = id
        self.order = order
        self.canRender = canRender
        self.render = { message, _ in AnyView(render(message)) }
    }
}
