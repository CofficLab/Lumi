import Foundation
import KitLLM
import ProviderMessage

// MARK: - Hook 枚举与上下文

/// 生命周期钩子点：所有可供插件挂载的时刻。
///
/// 每个 case 关联一个上下文值，钩子闭包通过上下文读取信息、
/// 可变钩子（如 `willSendToLLM`）还能修改上下文。
public enum LifecycleHookPoint: Sendable {
    /// LLM 请求发出前（可修改消息历史）。
    case willSendToLLM
    /// LLM 响应到达后。
    case didReceiveLLMResponse
    /// 回合开始。
    case turnStarted
    /// 回合完成（无论成功 / 失败 / 取消）。
    case turnFinished
    /// 工具执行前。
    case willExecuteTool
    /// 工具执行后。
    case didExecuteTool
}

// MARK: - 请求 / 响应上下文

/// `willSendToLLM` 钩子的上下文。
///
/// 钩子可以修改 `messages`（如注入 system 指令），返回修改后的版本。
/// 多个钩子按注册顺序串行执行，后一个拿到前一个的结果。
public struct WillSendToLLMContext: Sendable {
    /// 当前消息历史（可变）。
    public var messages: [LLMMessage]
    /// 会话 ID。
    public let conversationID: UUID

    public init(messages: [LLMMessage], conversationID: UUID) {
        self.messages = messages
        self.conversationID = conversationID
    }
}

/// `didReceiveLLMResponse` 钩子的上下文。
public struct DidReceiveLLMResponseContext: Sendable {
    /// LLM 返回的响应。
    public let response: LLMResponse
    /// 本次请求（发送前）的消息快照。
    public let requestMessages: [LLMMessage]
    /// 会话 ID。
    public let conversationID: UUID

    public init(
        response: LLMResponse,
        requestMessages: [LLMMessage],
        conversationID: UUID
    ) {
        self.response = response
        self.requestMessages = requestMessages
        self.conversationID = conversationID
    }
}

/// `turnStarted` / `turnFinished` 钩子的上下文。
public struct TurnLifecycleContext: Sendable {
    /// 会话 ID。
    public let conversationID: UUID
    /// 回合 ID。
    public let turnID: UUID
    /// 回合结束原因（仅 `turnFinished` 有效；`turnStarted` 时为 `nil`）。
    public let endReason: TurnEndReason?

    public init(
        conversationID: UUID,
        turnID: UUID,
        endReason: TurnEndReason? = nil
    ) {
        self.conversationID = conversationID
        self.turnID = turnID
        self.endReason = endReason
    }
}

/// 回合结束原因。
public enum TurnEndReason: String, Sendable, Equatable {
    case completed
    case failed
    case cancelled
    case suspended
}

/// `willExecuteTool` / `didExecuteTool` 钩子的上下文。
public struct ToolExecutionContext: Sendable {
    /// 会话 ID。
    public let conversationID: UUID
    /// 回合 ID。
    public let turnID: UUID
    /// 工具调用 ID。
    public let toolCallID: String
    /// 工具名称。
    public let toolName: String
    /// 工具参数（JSON 字符串）。
    public let arguments: String
    /// 工具执行结果（仅 `didExecuteTool` 有效；`willExecuteTool` 时为 `nil`）。
    public let result: String?
    /// 工具执行是否出错（仅 `didExecuteTool` 有效）。
    public let isError: Bool?

    public init(
        conversationID: UUID,
        turnID: UUID,
        toolCallID: String,
        toolName: String,
        arguments: String,
        result: String? = nil,
        isError: Bool? = nil
    ) {
        self.conversationID = conversationID
        self.turnID = turnID
        self.toolCallID = toolCallID
        self.toolName = toolName
        self.arguments = arguments
        self.result = result
        self.isError = isError
    }
}

// MARK: - 钩子闭包类型

/// `willSendToLLM` 可变钩子：可修改消息历史。
public typealias WillSendToLLMHook = @MainActor @Sendable (WillSendToLLMContext) async -> WillSendToLLMContext

/// 只读通知钩子：接收上下文但不修改。
public typealias DidReceiveLLMResponseHook = @MainActor @Sendable (DidReceiveLLMResponseContext) async -> Void
public typealias TurnStartedHook = @MainActor @Sendable (TurnLifecycleContext) async -> Void
public typealias TurnFinishedHook = @MainActor @Sendable (TurnLifecycleContext) async -> Void
public typealias WillExecuteToolHook = @MainActor @Sendable (ToolExecutionContext) async -> Void
public typealias DidExecuteToolHook = @MainActor @Sendable (ToolExecutionContext) async -> Void

/// 生命周期 Hook 的可取消注册句柄。
@MainActor
public protocol LifecycleHookHandle: AnyObject {
    func cancel()
}

// MARK: - Provider 协议

/// 生命周期钩子管理器协议。
///
/// 职责：
/// - 统一登记各生命周期钩子闭包
/// - 提供 `runWillSendToLLM` 串行执行可变钩子链
/// - 提供 `notify*` 方法广播只读钩子
///
/// 插件在 `onBoot` 中调用 `addHook` 注册钩子；宿主在 AgentLoop / LLM 调用
/// 的关键路径上调用对应的 `run*` / `notify*` 方法触发钩子。
///
/// 默认实现 `DefaultLifecycleHooksProvider` 提供开箱即用的钩子管理。
@MainActor
public protocol LifecycleHooksProviding: AnyObject, ObservableObject {
    // MARK: - 注册

    /// 注册 `willSendToLLM` 可变钩子。
    ///
    /// 多个钩子按注册顺序串行执行，后一个拿到前一个的结果。
    @discardableResult
    func addWillSendToLLMHook(_ hook: @escaping WillSendToLLMHook) -> any LifecycleHookHandle

    /// 注册 `didReceiveLLMResponse` 只读钩子。
    func addDidReceiveLLMResponseHook(_ hook: @escaping DidReceiveLLMResponseHook)

    /// 注册 `turnStarted` 只读钩子。
    func addTurnStartedHook(_ hook: @escaping TurnStartedHook)

    /// 注册 `turnFinished` 只读钩子。
    func addTurnFinishedHook(_ hook: @escaping TurnFinishedHook)

    /// 注册 `willExecuteTool` 只读钩子。
    func addWillExecuteToolHook(_ hook: @escaping WillExecuteToolHook)

    /// 注册 `didExecuteTool` 只读钩子。
    func addDidExecuteToolHook(_ hook: @escaping DidExecuteToolHook)

    // MARK: - 触发

    /// 串行执行所有 `willSendToLLM` 钩子，返回最终修改后的上下文。
    ///
    /// 调用方应在构造 `LLMRequest` 前调用本方法，用返回的 `messages`
    /// 替换原始消息历史。
    func runWillSendToLLM(_ context: WillSendToLLMContext) async -> WillSendToLLMContext

    /// 广播 `didReceiveLLMResponse` 事件。
    func notifyDidReceiveLLMResponse(_ context: DidReceiveLLMResponseContext) async

    /// 广播 `turnStarted` 事件。
    func notifyTurnStarted(_ context: TurnLifecycleContext) async

    /// 广播 `turnFinished` 事件。
    func notifyTurnFinished(_ context: TurnLifecycleContext) async

    /// 广播 `willExecuteTool` 事件。
    func notifyWillExecuteTool(_ context: ToolExecutionContext) async

    /// 广播 `didExecuteTool` 事件。
    func notifyDidExecuteTool(_ context: ToolExecutionContext) async
}

// MARK: - 默认空操作扩展

public extension LifecycleHooksProviding {
    func runWillSendToLLM(_ context: WillSendToLLMContext) async -> WillSendToLLMContext { context }
    func notifyDidReceiveLLMResponse(_ context: DidReceiveLLMResponseContext) async {}
    func notifyTurnStarted(_ context: TurnLifecycleContext) async {}
    func notifyTurnFinished(_ context: TurnLifecycleContext) async {}
    func notifyWillExecuteTool(_ context: ToolExecutionContext) async {}
    func notifyDidExecuteTool(_ context: ToolExecutionContext) async {}
}
