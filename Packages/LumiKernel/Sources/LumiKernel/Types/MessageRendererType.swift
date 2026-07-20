import Foundation
import SwiftUI

// MARK: - Chat Message Role

/// 聊天消息角色
public enum ChatMessageRole: String, Sendable {
    case user
    case assistant
    case system
    case tool
    case status
    case error
}

// MARK: - Message Renderer Item

/// 消息渲染器条目
///
/// 由插件通过 LumiPlugin.messageRenderers(kernel:) 贡献。
/// 用于根据消息内容/角色等条件选择合适的渲染器进行展示。
///
/// - Note: `canRender` 和 `render` 使用 `Any` 类型以避免对 LumiCoreMessage 的直接依赖。
///   调用方需要确保传入的消息类型与闭包期望的类型一致。
public struct MessageRendererItem: Identifiable, @unchecked Sendable {
    public let id: String
    public let order: Int
    public let canRender: @MainActor (Any) -> Bool
    public let render: @MainActor (Any, Binding<Bool>) -> AnyView

    public init<Content: View>(
        id: String,
        order: Int = 0,
        canRender: @escaping @MainActor (Any) -> Bool,
        @ViewBuilder render: @escaping @MainActor (Any, Binding<Bool>) -> Content
    ) {
        self.id = id
        self.order = order
        self.canRender = canRender
        self.render = { AnyView(render($0, $1)) }
    }

    public init<Content: View>(
        id: String,
        order: Int = 0,
        canRender: @escaping @MainActor (Any) -> Bool,
        @ViewBuilder render: @escaping @MainActor (Any) -> Content
    ) {
        self.id = id
        self.order = order
        self.canRender = canRender
        self.render = { message, _ in AnyView(render(message)) }
    }
}
