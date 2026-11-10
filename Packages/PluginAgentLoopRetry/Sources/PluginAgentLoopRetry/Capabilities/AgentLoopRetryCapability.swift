import Foundation
import ProviderAgentLoop
import ProviderConversation
import ProviderMessage

/// 重试协调器关注的回合状态。
///
/// 只保留协调器需要区分的两种状态，避免把 `AgentLoopProviding` 的完整状态面
/// 泄漏到业务层。
enum AgentLoopRetryTurnState: Equatable {
    /// 回合处于失败态，可发起重试。
    case failed
    /// 其他状态（运行中 / 已完成 / 已取消 / 挂起）。
    case other
}

/// 重试协调器需要的最小回合能力边界。
///
/// 订阅回合事件、判断可重试失败、重启回合——只依赖下面三个操作。
@MainActor
protocol AgentLoopRetryCapability: AnyObject {
    /// 订阅回合事件；回调在主线程同步执行。
    ///
    /// - Parameter callback: 接收插件自有事件，不泄漏 `AgentLoopEvent`。
    /// - Returns: 观察句柄，不再需要时 `cancel()`。
    func addTurnObserver(_ callback: @escaping (AgentLoopRetryEvent) -> Void) -> any AgentLoopRetryObserverHandle

    /// 查询指定会话最近一次失败；没有失败记录时返回 `nil`。
    func lastFailure(for conversationID: UUID) -> AgentLoopFailure?

    /// 查询指定会话的回合状态。
    func turnState(for conversationID: UUID) -> AgentLoopRetryTurnState

    /// 暂停重试期间会话被删除时回调；协调器必须取消该会话的延迟重试。
    func addConversationDeletionObserver(_ callback: @escaping (UUID) -> Void) -> any AgentLoopRetryObserverHandle

    /// 会话是否仍然存在。退避结束后不能为已删除的会话启动新回合。
    func conversationExists(for conversationID: UUID) -> Bool

    /// 重启指定会话中紧接 `failedTurnID` 之后的回合。
    func retryTurn(in conversationID: UUID, after failedTurnID: UUID) async throws -> AgentLoopOutcome
}

/// 插件自有的回合事件，不向消费方泄漏 `AgentLoopEvent`。
enum AgentLoopRetryEvent {
    /// 回合开始。
    case started(conversationID: UUID, turnID: UUID)
    /// 回合失败。
    case failed(conversationID: UUID, turnID: UUID)
    /// 回合完成或被取消。
    case settled(conversationID: UUID)
    /// LLM 成功返回过一次（工具调用或正文），失败不再是背靠背的。
    case progressReceived(conversationID: UUID)
}

/// 重试能力对回合事件的观察句柄。
@MainActor
protocol AgentLoopRetryObserverHandle: AnyObject {
    /// 停止接收后续事件。重复调用无副作用。
    func cancel()
}

/// 重试协调器关注的失败信息。
///
/// `AgentLoopFailure` 是纯数据值类型（不含 Provider 行为），复用它不会把
/// Provider 的接口面泄漏到业务层。
typealias AgentLoopRetryFailure = AgentLoopFailure

/// 将内核的 `AgentLoopProviding` 收窄为重试协调器所需的能力。
@MainActor
final class AgentLoopRetryCapabilityAdapter: AgentLoopRetryCapability {
    private let agentLoop: any AgentLoopProviding
    private let conversations: (any ConversationManaging)?

    /// - Parameter conversations: 未注入时退化为「始终存在且收不到删除事件」，
    ///   仅供不关心会话生命周期的测试替身使用；生产必须注入。
    init(agentLoop: any AgentLoopProviding, conversations: (any ConversationManaging)? = nil) {
        self.agentLoop = agentLoop
        self.conversations = conversations
    }

    func addTurnObserver(_ callback: @escaping (AgentLoopRetryEvent) -> Void) -> any AgentLoopRetryObserverHandle {
        AgentLoopRetryObserverHandleBox(
            agentLoop.addAgentLoopObserver { event in
                switch event {
                case .started(let conversationID, let turnID):
                    callback(.started(conversationID: conversationID, turnID: turnID))
                case .failed(let conversationID, let turnID, _):
                    callback(.failed(conversationID: conversationID, turnID: turnID))
                case .completed(let conversationID, _), .cancelled(let conversationID, _):
                    callback(.settled(conversationID: conversationID))
                case .toolCallsReceived(let conversationID, _, _, _),
                     .llmResponseReceived(let conversationID, _, _):
                    callback(.progressReceived(conversationID: conversationID))
                case .suspended:
                    break
                }
            }
        )
    }

    func lastFailure(for conversationID: UUID) -> AgentLoopFailure? {
        agentLoop.lastFailure(for: conversationID)
    }

    func turnState(for conversationID: UUID) -> AgentLoopRetryTurnState {
        agentLoop.state(for: conversationID) == .failed ? .failed : .other
    }

    func addConversationDeletionObserver(_ callback: @escaping (UUID) -> Void) -> any AgentLoopRetryObserverHandle {
        guard let conversations else {
            return AgentLoopRetryClosureHandle {}
        }
        let handle = conversations.addConversationObserver { event in
            if case .deleted(let conversationID) = event {
                callback(conversationID)
            }
        }
        return AgentLoopRetryClosureHandle { handle.cancel() }
    }

    func conversationExists(for conversationID: UUID) -> Bool {
        guard let conversations else { return true }
        return conversations.conversations.contains { $0.id == conversationID }
    }

    func retryTurn(in conversationID: UUID, after failedTurnID: UUID) async throws -> AgentLoopOutcome {
        try await agentLoop.retryTurn(in: conversationID, after: failedTurnID)
    }
}

/// 用闭包包装不同 Provider 的观察句柄，统一成协调器自己的句柄类型。
@MainActor
private final class AgentLoopRetryClosureHandle: AgentLoopRetryObserverHandle {
    private let onCancel: () -> Void

    init(_ onCancel: @escaping () -> Void) {
        self.onCancel = onCancel
    }

    func cancel() {
        onCancel()
    }
}

/// 包装 Provider 的观察句柄，避免把 Provider 句柄类型泄漏给消费方。
@MainActor
private final class AgentLoopRetryObserverHandleBox: AgentLoopRetryObserverHandle {
    private let handle: any AgentLoopObserverHandle

    init(_ handle: any AgentLoopObserverHandle) {
        self.handle = handle
    }

    func cancel() {
        handle.cancel()
    }
}

/// 向会话时间线写入一条重试系统消息所需的最小消息能力。
@MainActor
protocol AgentLoopRetryMessageCapability: AnyObject {
    /// 写入一条不进入 LLM 上下文的系统消息。
    func insertRetryNotice(_ message: Message)
}

/// 将内核的 `MessageManaging` 收窄为重试协调器所需的消息能力。
@MainActor
final class AgentLoopRetryMessageCapabilityAdapter: AgentLoopRetryMessageCapability {
    private let messages: any MessageManaging

    init(messages: any MessageManaging) {
        self.messages = messages
    }

    func insertRetryNotice(_ message: Message) {
        messages.insertMessage(message, to: message.conversationID)
    }
}
