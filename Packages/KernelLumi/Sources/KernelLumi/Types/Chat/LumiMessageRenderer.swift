import SwiftUI

/// 消息渲染器条目:由插件贡献,被 `MessageRendering` 管理器统一注册和匹配。
///
/// 渲染闭包 `render` 接收 2 个参数:
/// - `LumiChatMessage` — 当前要渲染的消息
/// - `LumiResponseVerbosity` — 当前对话的响应详细程度(brief / standard / detailed)
public struct LumiMessageRendererItem: Identifiable, @unchecked Sendable {
    public let id: String
    public let order: Int
    public let canRender: @MainActor (LumiChatMessage) -> Bool
    public let render: @MainActor (LumiChatMessage, LumiResponseVerbosity) -> AnyView

    /// 主构造器:render 闭包接收 message 与 verbosity。
    public init<Content: View>(
        id: String,
        order: Int = 0,
        canRender: @escaping @MainActor (LumiChatMessage) -> Bool,
        @ViewBuilder render: @escaping @MainActor (LumiChatMessage, LumiResponseVerbosity) -> Content
    ) {
        self.id = id
        self.order = order
        self.canRender = canRender
        self.render = { message, verbosity in
            AnyView(render(message, verbosity))
        }
    }
}