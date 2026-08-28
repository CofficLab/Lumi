import Foundation
import Combine

/// `LifecycleHooksProviding` 默认实现。
///
/// 持有所有钩子闭包的有序数组；`runWillSendToLLM` 串行执行可变链，
/// `notify*` 串行广播只读钩子。线程安全由 `@MainActor` 保证
/// （所有钩子均在 MainActor 上执行，与现有 AgentLoop 一致）。
@MainActor
public final class DefaultLifecycleHooksProvider: LifecycleHooksProviding {
    @Published public private(set) var revision: Int = 0

    // MARK: - Hook Storage

    private var willSendToLLMHooks: [WillSendToLLMHook] = []
    private var didReceiveLLMResponseHooks: [DidReceiveLLMResponseHook] = []
    private var turnStartedHooks: [TurnStartedHook] = []
    private var turnFinishedHooks: [TurnFinishedHook] = []
    private var willExecuteToolHooks: [WillExecuteToolHook] = []
    private var didExecuteToolHooks: [DidExecuteToolHook] = []

    public init() {}

    // MARK: - Registration

    public func addWillSendToLLMHook(_ hook: @escaping WillSendToLLMHook) {
        willSendToLLMHooks.append(hook)
        revision += 1
    }

    public func addDidReceiveLLMResponseHook(_ hook: @escaping DidReceiveLLMResponseHook) {
        didReceiveLLMResponseHooks.append(hook)
        revision += 1
    }

    public func addTurnStartedHook(_ hook: @escaping TurnStartedHook) {
        turnStartedHooks.append(hook)
        revision += 1
    }

    public func addTurnFinishedHook(_ hook: @escaping TurnFinishedHook) {
        turnFinishedHooks.append(hook)
        revision += 1
    }

    public func addWillExecuteToolHook(_ hook: @escaping WillExecuteToolHook) {
        willExecuteToolHooks.append(hook)
        revision += 1
    }

    public func addDidExecuteToolHook(_ hook: @escaping DidExecuteToolHook) {
        didExecuteToolHooks.append(hook)
        revision += 1
    }

    // MARK: - Execution

    /// 串行执行所有 `willSendToLLM` 钩子。
    ///
    /// 钩子按注册顺序串行执行；后一个拿到前一个修改后的 `messages`，
    /// 形成消息处理管道。任一钩子中断链并返回已处理的上下文
    /// （不吞异常，保证已完成的修改不丢失）。
    public func runWillSendToLLM(_ context: WillSendToLLMContext) async -> WillSendToLLMContext {
        var current = context
        for hook in willSendToLLMHooks {
            current = await hook(current)
        }
        return current
    }

    /// 广播 `didReceiveLLMResponse`：串行通知所有注册的钩子。
    public func notifyDidReceiveLLMResponse(_ context: DidReceiveLLMResponseContext) async {
        for hook in didReceiveLLMResponseHooks {
            await hook(context)
        }
    }

    /// 广播 `turnStarted`。
    public func notifyTurnStarted(_ context: TurnLifecycleContext) async {
        for hook in turnStartedHooks {
            await hook(context)
        }
    }

    /// 广播 `turnFinished`。
    public func notifyTurnFinished(_ context: TurnLifecycleContext) async {
        for hook in turnFinishedHooks {
            await hook(context)
        }
    }

    /// 广播 `willExecuteTool`。
    public func notifyWillExecuteTool(_ context: ToolExecutionContext) async {
        for hook in willExecuteToolHooks {
            await hook(context)
        }
    }

    /// 广播 `didExecuteTool`。
    public func notifyDidExecuteTool(_ context: ToolExecutionContext) async {
        for hook in didExecuteToolHooks {
            await hook(context)
        }
    }
}
