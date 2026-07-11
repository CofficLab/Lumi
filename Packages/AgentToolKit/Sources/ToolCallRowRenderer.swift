import Foundation
import SwiftUI

/// 行渲染器所需的助手消息上下文（避免 AgentToolKit 依赖 LumiCoreKit）。
public struct ToolCallRowMessageContext: Sendable {
    public let conversationId: UUID
    public let assistantMessageId: UUID
    public let verbosityRawValue: String?

    public init(conversationId: UUID, assistantMessageId: UUID, verbosityRawValue: String? = nil) {
        self.conversationId = conversationId
        self.assistantMessageId = assistantMessageId
        self.verbosityRawValue = verbosityRawValue
    }
}

/// 单个 ToolCall 的自定义行渲染器
///
/// 插件可以实现此协议来为特定状态的 ToolCall 提供自定义视图，
/// 替代 `MessageRendererPlugin` 中的默认 `ToolCallRow`。
///
/// 与 `SuperMessageRenderer`（消息级别）不同，这是 **ToolCall 行级别** 的渲染扩展点。
/// `MessageRendererPlugin` 在遍历 toolCalls 时，会先查询 `ToolCallRowRendererRegistry`
/// 是否有匹配的渲染器；有则使用自定义视图，无则回退到默认的 `ToolCallRow`。
///
/// ## 使用示例
///
/// ```swift
/// struct AskUserRowRenderer: ToolCallRowRenderer {
///     static let id = "ask-user-row"
///     static let priority = 100
///
///     func canRender(toolCall: ToolCall) -> Bool {
///         toolCall.result?.awaitingUserResponse == true
///     }
///
///     @MainActor
///     func render(toolCall: ToolCall, message: ToolCallRowMessageContext) -> AnyView {
///         AskUserPendingView(toolCall: toolCall)
///     }
/// }
/// ```
public protocol ToolCallRowRenderer {
    /// 渲染器唯一标识
    static var id: String { get }

    /// 渲染器优先级（数字越大越先匹配）
    static var priority: Int { get }

    /// 判断是否可以为该 ToolCall 提供自定义视图
    func canRender(toolCall: ToolCall) -> Bool

    /// 渲染自定义 ToolCall 行视图
    @MainActor
    func render(toolCall: ToolCall, message: ToolCallRowMessageContext) -> AnyView
}

/// 默认实现
extension ToolCallRowRenderer {
    public static var priority: Int { 0 }
}

/// ToolCall 行渲染器的全局注册表
///
/// 插件在 `onRegister()` 或 `configureRuntime()` 阶段调用 `register()` 注册自定义渲染器。
/// `MessageRendererPlugin` 在渲染每个 ToolCall 时查询 `findRenderer(for:)`。
///
/// 注册表按优先级降序维护，查询时返回第一个 `canRender == true` 的渲染器。
@MainActor
public final class ToolCallRowRendererRegistry: ObservableObject {
    public static let shared = ToolCallRowRendererRegistry()

    private var renderers: [any ToolCallRowRenderer] = []

    private init() {}

    /// 注册一个渲染器
    public func register(_ renderer: some ToolCallRowRenderer) {
        if let index = renderers.firstIndex(where: { type(of: $0).id == type(of: renderer).id }) {
            renderers[index] = renderer
        } else {
            renderers.append(renderer)
        }
        renderers.sort { type(of: $0).priority > type(of: $1).priority }
    }

    /// 查找匹配的渲染器
    public func findRenderer(for toolCall: ToolCall) -> (any ToolCallRowRenderer)? {
        renderers.first { $0.canRender(toolCall: toolCall) }
    }
}
