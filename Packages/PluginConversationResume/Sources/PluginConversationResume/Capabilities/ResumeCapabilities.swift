import Foundation
import ProviderAgentLoop
import ProviderConversation
import ProviderMessage

/// 「继续」功能所需的最小 AgentLoop 能力。
///
/// 刻意不暴露完整的 `AgentLoopProviding`：本功能只需要
/// 「这个会话的回合是什么状态」和「能不能启动一个新回合」两件事。
@MainActor
protocol ResumeAgentLoopCapability: AnyObject {
    /// 查询会话当前的回合状态。
    func turnState(for conversationID: UUID) -> ResumeEligibility.AgentLoopStateSnapshot

    /// 启动一个新回合。
    ///
    /// 恢复走的是**新回合**而不是重试旧回合：旧回合的 `turnID` 已经在崩溃
    /// 时丢失，AgentLoop 侧的 `retryTurn(after:)` 校验必然失败。
    func startTurn(for conversationID: UUID) async
}

@MainActor
protocol ResumeAgentLoopObserverHandle: AnyObject {
    func cancel()
}

/// 将内核 `AgentLoopProviding` 收窄为「继续」功能所需的能力。
@MainActor
final class ResumeAgentLoopCapabilityAdapter: ResumeAgentLoopCapability {
    private final class ObserverHandle: ResumeAgentLoopObserverHandle {
        private let cancelAction: () -> Void
        private var isCancelled = false

        init(cancelAction: @escaping () -> Void) {
            self.cancelAction = cancelAction
        }

        func cancel() {
            guard !isCancelled else { return }
            isCancelled = true
            cancelAction()
        }
    }

    private let agentLoop: any AgentLoopProviding

    init(agentLoop: any AgentLoopProviding) {
        self.agentLoop = agentLoop
    }

    func turnState(for conversationID: UUID) -> ResumeEligibility.AgentLoopStateSnapshot {
        ResumeEligibility.AgentLoopStateSnapshot(agentLoop.state(for: conversationID))
    }

    func startTurn(for conversationID: UUID) async {
        // 回合已经在跑时不能重复启动。
        guard !agentLoop.isRunning(for: conversationID) else { return }
        _ = try? await agentLoop.runTurn(in: conversationID)
    }
}

/// 「继续」功能所需的最小消息能力。
@MainActor
protocol ResumeMessageCapability: AnyObject {
    /// 读取会话的消息快照（按时间升序）。
    func messages(for conversationID: UUID) async -> [Message]

    /// 写入一条消息。
    func insertMessage(_ message: Message, to conversationID: UUID)

    @discardableResult
    func addObserver(
        _ callback: @escaping (UUID) -> Void
    ) -> any ResumeMessageObserverHandle
}

@MainActor
protocol ResumeMessageObserverHandle: AnyObject {
    func cancel()
}

/// 将内核 `MessageManaging` 收窄为「继续」功能所需的能力。
@MainActor
final class ResumeMessageCapabilityAdapter: ResumeMessageCapability {
    private final class ObserverHandle: ResumeMessageObserverHandle {
        private let cancelAction: () -> Void
        private var isCancelled = false

        init(cancelAction: @escaping () -> Void) {
            self.cancelAction = cancelAction
        }

        func cancel() {
            guard !isCancelled else { return }
            isCancelled = true
            cancelAction()
        }
    }

    private let messages: any MessageManaging

    init(messages: any MessageManaging) {
        self.messages = messages
    }

    func messages(for conversationID: UUID) async -> [Message] {
        await messages.messagesSnapshot(in: conversationID)
    }

    func insertMessage(_ message: Message, to conversationID: UUID) {
        messages.insertMessage(message, to: conversationID)
    }

    @discardableResult
    func addObserver(
        _ callback: @escaping (UUID) -> Void
    ) -> any ResumeMessageObserverHandle {
        let handle = messages.addMessageInsertedObserver { _, conversationID in
            callback(conversationID)
        }
        return ObserverHandle {
            handle.cancel()
        }
    }
}

/// 「继续」功能所需的最小会话选择能力。
@MainActor
protocol ResumeConversationCapability: AnyObject {
    /// 当前选中的会话 ID。
    var selectedConversationID: UUID? { get }

    @discardableResult
    func addObserver(
        _ callback: @escaping (UUID?) -> Void
    ) -> any ResumeConversationObserverHandle
}

@MainActor
protocol ResumeConversationObserverHandle: AnyObject {
    func cancel()
}

/// 将内核 `ConversationManaging` 收窄为「继续」功能所需的能力。
@MainActor
final class ResumeConversationCapabilityAdapter: ResumeConversationCapability {
    private final class ObserverHandle: ResumeConversationObserverHandle {
        private let cancelAction: () -> Void
        private var isCancelled = false

        init(cancelAction: @escaping () -> Void) {
            self.cancelAction = cancelAction
        }

        func cancel() {
            guard !isCancelled else { return }
            isCancelled = true
            cancelAction()
        }
    }

    private let conversations: any ConversationManaging

    init(conversations: any ConversationManaging) {
        self.conversations = conversations
    }

    var selectedConversationID: UUID? {
        conversations.selectedConversationID
    }

    @discardableResult
    func addObserver(
        _ callback: @escaping (UUID?) -> Void
    ) -> any ResumeConversationObserverHandle {
        let handle = conversations.addSelectedConversationObserver(callback)
        return ObserverHandle {
            handle.cancel()
        }
    }
}
