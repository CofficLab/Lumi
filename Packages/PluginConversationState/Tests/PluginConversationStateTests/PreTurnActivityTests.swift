import Foundation
import ProviderAgentLoop
import ProviderConversationState
import ProviderMessage
import ProviderMessageSender
import Testing
@testable import PluginConversationState

/// 复现「第二轮起，发送前的活动状态被上一轮终态吞掉」。
///
/// # 现象
///
/// 第一回合结束后，`ConversationStateSnapshot.agentLoopState` 停在终态
/// （`.completed` / `.failed` / `.cancelled`）。第二轮发送时，
/// `MessageSenderStateObserver` 只写 `activity = .sending`、**不写**
/// `agentLoopState`，于是 Provider 合并更新时沿用上一轮的终态。
///
/// `acceptsActivity` 对终态一律拒绝 activity，于是 `.sending` 被吞成 nil，
/// Standard / Detailed 消息列表的「正在发送消息…」活动行随之消失。
///
/// # 为什么第一轮正常
///
/// 初始 `agentLoopState` 是 `.idle`，而 `.idle` 分支对 `.sending` 有特批。
/// 一旦第一轮把状态推到终态，这个特批就再也够不着了——问题只在第二轮起出现。
///
/// # 语义要点
///
/// `agentLoopState` 描述的是**上一轮**回合的结局（它被保留在快照里，不重置），
/// `activity` 描述的是**这一轮**投递阶段的状态。用上一轮的终态去否决这一轮
/// 的合法动作，是把两个时间尺度混在了一起。
@Suite("pre-turn 活动状态")
@MainActor
struct PreTurnActivityTests {

    /// 复现主线：第一轮结束后，第二轮的发送前活动必须仍然可见。
    @Test("第二轮的发送前活动不得被上一轮终态吞掉")
    func secondTurnSendingActivitySurvivesPreviousTerminalState() {
        for terminal in [AgentLoopState.completed, .failed, .cancelled] {
            let provider = ConversationStateProvider()
            let conversationID = UUID()

            // 第一轮：回合跑完后进入终态。
            provider.update(
                conversationID: conversationID,
                agentLoopState: .running,
                activity: .thinking
            )
            provider.update(
                conversationID: conversationID,
                agentLoopState: terminal,
                clearActivity: true
            )
            #expect(provider.state(for: conversationID).activity == nil)

            // 第二轮：消息投递阶段写入 `.sending`（不携带 agentLoopState）。
            provider.update(conversationID: conversationID, activity: .sending)

            #expect(
                provider.state(for: conversationID).activity == .sending,
                """
                \(terminal) 终态之后的新一轮发送，其 pre-turn 活动状态被吞掉了。\
                活动行会整段消失，用户看不到「正在发送消息…」。
                """
            )
        }
    }

    /// 走真实的观察者链路：`MessageSenderEvent.started` 到达后，
    /// 会话状态里必须出现 `.sending`。
    ///
    /// 这条用例锁定的是**观察者 → Provider** 这条真实路径，
    /// 而不只是 Provider 的孤立行为。
    @Test("MessageSender 事件到达后必须写入发送中活动")
    func messageSenderStartedWritesSendingActivity() {
        let provider = ConversationStateProvider()
        let sender = MessageSenderEventStub()
        let observer = MessageSenderStateObserver(sender: sender, provider: provider)
        let conversationID = UUID()

        // 第一轮结束：进入终态。
        provider.update(
            conversationID: conversationID,
            agentLoopState: .completed,
            clearActivity: true
        )

        // 第二轮发送：MessageSender 发布 `.started`。
        sender.emit(.started(conversationID: conversationID))

        #expect(
            provider.state(for: conversationID).activity == .sending,
            "发送前活动状态缺失，消息列表的活动行不会显示"
        )
        observer.cancel()
    }

    /// 守卫的另一半必须保住：终态回合**不得**承载回合期 activity。
    ///
    /// 这是 #891 修复最容易踩的坑——若为了放行 `.sending` 而把终态整体放开，
    /// 迟到的 ToolManager 事件会把 `.waitingForUser` 写回已死掉的回合，
    /// 界面永远显示「等待你的输入…」（见 `AuthorizationActivityResidueTests`）。
    @Test("终态回合仍不得承载回合期活动")
    func terminalTurnStillRejectsTurnScopedActivity() {
        for terminal in [AgentLoopState.completed, .failed, .cancelled] {
            let provider = ConversationStateProvider()
            let conversationID = UUID()

            provider.update(
                conversationID: conversationID,
                agentLoopState: terminal,
                clearActivity: true
            )

            // 迟到的回合期事件。
            for stale in [
                ConversationActivity.thinking,
                .executingTool,
                .waitingForUser,
            ] {
                provider.update(conversationID: conversationID, activity: stale)
                #expect(
                    provider.state(for: conversationID).activity == nil,
                    "\(terminal) 回合上不应残留 \(stale)"
                )
            }
        }
    }

    /// `.sending` 期间 `agentLoopState` 必须保持上一轮的终态。
    ///
    /// 这一条是 #891 修复的**护栏**：pre-turn 窗口里 AgentLoop 的回合确实
    /// 还没开始，把 `agentLoopState` 改写成 `.idle` 会谎报「没有回合在跑」，
    /// 于是 `canStop` 变成 false——用户按下停止按钮没反应，
    /// 而回合其实正由 AgentLoop 托管着跑。
    @Test("发送前窗口不得把回合状态改写成 idle")
    func sendingActivityDoesNotResetAgentLoopState() {
        let provider = ConversationStateProvider()
        let conversationID = UUID()

        provider.update(
            conversationID: conversationID,
            agentLoopState: .completed,
            clearActivity: true
        )
        provider.update(conversationID: conversationID, activity: .sending)

        let snapshot = provider.state(for: conversationID)
        #expect(snapshot.agentLoopState == .completed)
        #expect(snapshot.activity == .sending)
    }
}

/// 只回放 `MessageSenderEvent` 的发送器替身。
///
/// 只需要观察者注册入口，其余成员不参与本组用例。
@MainActor
private final class MessageSenderEventStub: MessageSendingProviding {
    private var callback: ((MessageSenderEvent) -> Void)?

    func addMessageSenderObserver(
        _ callback: @escaping (MessageSenderEvent) -> Void
    ) -> any MessageSenderObserverHandle {
        self.callback = callback
        return MessageSenderObserverHandleStub { [weak self] in
            self?.callback = nil
        }
    }

    func emit(_ event: MessageSenderEvent) {
        callback?(event)
    }

    func addSendingStateObserver(
        _ callback: @escaping (Bool) -> Void
    ) -> any SendingStateObserverHandle {
        NoopSendingStateObserverHandle()
    }

    // MARK: - 未参与本组用例的成员

    var isSending: Bool { false }
    var pendingImageAttachments: [UserImageAttachment] { [] }
    var pendingFileAttachments: [UserFileAttachment] { [] }

    func addImageAttachment(_ attachment: UserImageAttachment) {}
    func removeImageAttachment(id: UUID) {}
    func clearImageAttachments() {}
    func addFileAttachment(_ attachment: UserFileAttachment) {}
    func removeFileAttachment(id: UUID) {}
    func clearFileAttachments() {}

    func pendingMessages(for conversationID: UUID) -> [PendingChatMessage] { [] }
    func cancelPendingMessage(id: UUID, in conversationID: UUID) {}

    @discardableResult
    func commitUserMessage(_ content: String, conversationID: UUID?) throws -> MessageSendCommit? {
        nil
    }

    @discardableResult
    func commitUserMessage(
        _ content: String,
        imageAttachments: [UserImageAttachment],
        fileAttachments: [UserFileAttachment],
        conversationID: UUID?
    ) throws -> MessageSendCommit? {
        nil
    }

    func commitUserMessageInBackground(
        _ content: String,
        imageAttachments: [UserImageAttachment],
        fileAttachments: [UserFileAttachment],
        conversationID: UUID?
    ) async throws -> MessageSendCommit? {
        nil
    }

    func startTurn(for commit: MessageSendCommit) async {}

    func sendMessage(_ content: String, conversationID: UUID?) async throws {}

    func sendMessage(
        _ content: String,
        imageAttachments: [UserImageAttachment],
        fileAttachments: [UserFileAttachment],
        conversationID: UUID?
    ) async throws {}

    func cancelCurrentRequest() {}

    @discardableResult
    func resumeTurn(
        in conversationID: UUID,
        request: AgentTurnResumeRequest
    ) async throws -> AgentLoopOutcome {
        .completed
    }
}

@MainActor
private final class MessageSenderObserverHandleStub: MessageSenderObserverHandle {
    private var cancellation: (() -> Void)?

    init(cancellation: @escaping () -> Void) {
        self.cancellation = cancellation
    }

    func cancel() {
        cancellation?()
        cancellation = nil
    }
}

@MainActor
private final class NoopSendingStateObserverHandle: SendingStateObserverHandle {
    func cancel() {}
}
