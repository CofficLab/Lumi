import KitAgentTool
import SwiftUI

/// 工具调用行渲染所需的助手消息上下文。
public struct ToolCallRowMessageContext: Sendable {
    public let conversationId: UUID
    public let assistantMessageId: UUID
    public let verbosityRawValue: String?

    public init(
        conversationId: UUID,
        assistantMessageId: UUID,
        verbosityRawValue: String? = nil
    ) {
        self.conversationId = conversationId
        self.assistantMessageId = assistantMessageId
        self.verbosityRawValue = verbosityRawValue
    }
}

/// 单个 ToolCall 的自定义行渲染器。
public protocol ToolCallRowRenderer {
    static var id: String { get }
    static var priority: Int { get }
    func canRender(toolCall: ToolCall) -> Bool
    @MainActor
    func render(toolCall: ToolCall, message: ToolCallRowMessageContext) -> AnyView
}

extension ToolCallRowRenderer {
    public static var priority: Int { 0 }
}

/// 工具调用行渲染能力。
///
/// 与 `MessageRenderingProviding` 平级：消息级渲染器负责选择整条消息，
/// 工具调用渲染器负责替换 assistant 消息内部的单个 ToolCall 行。
@MainActor
public protocol ToolCallRenderingProviding: AnyObject {
    var allRenderers: [any ToolCallRowRenderer] { get }
    func register(_ renderer: any ToolCallRowRenderer)
    func unregister(id: String)
    func renderer(for toolCall: ToolCall) -> (any ToolCallRowRenderer)?
}

@MainActor
public final class DefaultToolCallRenderingProviding: ToolCallRenderingProviding {
    public private(set) var allRenderers: [any ToolCallRowRenderer] = []

    public init() {}

    public func register(_ renderer: any ToolCallRowRenderer) {
        let rendererType = type(of: renderer)
        allRenderers.removeAll { type(of: $0).id == rendererType.id }
        allRenderers.append(renderer)
        allRenderers.sort { type(of: $0).priority > type(of: $1).priority }
    }

    public func unregister(id: String) {
        allRenderers.removeAll { type(of: $0).id == id }
    }

    public func renderer(for toolCall: ToolCall) -> (any ToolCallRowRenderer)? {
        allRenderers.first { $0.canRender(toolCall: toolCall) }
    }
}
