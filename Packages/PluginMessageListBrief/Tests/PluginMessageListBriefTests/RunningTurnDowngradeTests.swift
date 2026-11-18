import Foundation
import ProviderAgentLoop
import ProviderConversation
import ProviderMessage
import Testing
import KitMessageList
@testable import PluginMessageListBrief

/// 回归 #312：Brief 重建窗口时，pending 判定用裸 `turnID == nil` 识别
/// 「新 turn 正在启动」。但发送器在 turnID 生成前就落库用户消息，运行中
/// turn 的用户消息同样是 `turnID == nil`，于是当前 turn 被永久降级成
/// completed：运行态、计时器与实时活动全部丢失。
/// pending 只应针对「晚于最新可见 turn 开始时间且未被认领」的用户消息。
@MainActor
struct RunningTurnDowngradeTests {
    private let conversationID = UUID()

    // MARK: - Stubs（与 ListPresentationTests 同型的最小实现）

    private final class StubMessages: MessageListMessageCapability {
        let snapshot: [Message]
        init(snapshot: [Message]) { self.snapshot = snapshot }

        private func sortedMessages(in conversationID: UUID) -> [Message] {
            snapshot
                .filter { $0.conversationID == conversationID }
                .sorted { $0.createdAt < $1.createdAt }
        }

        func messagesSnapshot(in conversationID: UUID) async -> [Message] {
            sortedMessages(in: conversationID)
        }

        func messagePageAsync(
            for conversationID: UUID,
            limit: Int,
            beforeMessageID: UUID?,
            includesToolMessages: Bool
        ) async -> [Message] {
            let all = sortedMessages(in: conversationID)
            guard let beforeMessageID else { return Array(all.suffix(limit)) }
            guard let index = all.firstIndex(where: { $0.id == beforeMessageID }) else { return [] }
            return Array(all[max(0, index - limit)..<index])
        }

        func hasEarlierMessagesAsync(
            for conversationID: UUID,
            beforeMessageID: UUID?,
            includesToolMessages: Bool
        ) async -> Bool {
            let all = sortedMessages(in: conversationID)
            guard let beforeMessageID else { return all.count > 10 }
            guard let index = all.firstIndex(where: { $0.id == beforeMessageID }) else { return false }
            return index > 0
        }
    }

    private final class StubConversations: MessageListConversationCapability {
        let selected: UUID?
        init(selected: UUID?) { self.selected = selected }
        var selectedConversationID: UUID? { selected }
        func verbosity(for conversationID: UUID?) -> ResponseVerbosity { .brief }
    }

    private final class StubAgentLoop: MessageListAgentLoopCapability {
        let stateToReturn: AgentLoopState
        init(state: AgentLoopState) { self.stateToReturn = state }
        func state(for conversationID: UUID) -> AgentLoopState { stateToReturn }
    }

    private func makeServices(messages: [Message], agentState: AgentLoopState) -> MessageListServices {
        MessageListServices(
            conversations: StubConversations(selected: conversationID),
            developerMode: nil,
            messages: StubMessages(snapshot: messages),
            rendering: nil,
            agentTurn: StubAgentLoop(state: agentState)
        )
    }

    /// 运行中 turn 的消息序列：用户消息不带 turnID（生产语义，#312），
    /// 随后是该 turn 的过程消息。
    private func runningTurnMessages(base: Date) -> (messages: [Message], turnID: UUID) {
        let turnID = UUID()
        let messages = [
            Message(
                conversationID: conversationID, role: .user,
                content: "帮我查一下", createdAt: base
            ),
            Message(
                conversationID: conversationID, role: .assistant,
                content: "正在调用工具", createdAt: base.addingTimeInterval(1), turnID: turnID
            ),
            Message(
                conversationID: conversationID, role: .assistant,
                content: "工具仍在运行", createdAt: base.addingTimeInterval(2), turnID: turnID
            ),
        ]
        return (messages, turnID)
    }

    @Test("运行中 turn 的用户消息不算 pending：running 不被降级，实时活动保留")
    func runningTurnWithClaimedUserMessageStaysRunning() async {
        let base = Date()
        let (messages, _) = runningTurnMessages(base: base)
        let vm = ConversationMessageListVM(services: makeServices(messages: messages, agentState: .running))

        await vm.activate(conversationID: conversationID)

        // agentTurns 最新在前：当前 turn 在首位。
        let currentTurn = vm.agentTurns.first
        #expect(currentTurn?.record?.state == .running)
        #expect(currentTurn?.isShowingProcess == true)
        #expect(currentTurn?.acceptsLiveActivity == true)
        // 不应出现 pending item。
        #expect(vm.agentTurns.count == 1)
        #expect(vm.agentTurns.allSatisfy { $0.pendingAnchorMessageID == nil })
    }

    @Test("新 turn 启动的未认领用户消息仍是 pending：旧 turn 照常降级")
    func genuinelyPendingUserMessageStillDowngradesOldTurn() async {
        let base = Date()
        let (messages, _) = runningTurnMessages(base: base)
        // 晚于最新 turn 开始时间的用户消息：新 turn 正在启动，未被认领。
        let pendingUser = Message(
            conversationID: conversationID, role: .user,
            content: "再来一个", createdAt: base.addingTimeInterval(5)
        )
        let vm = ConversationMessageListVM(services: makeServices(
            messages: messages + [pendingUser],
            agentState: .running
        ))

        await vm.activate(conversationID: conversationID)

        // 旧 turn 被降级为 completed（避免其 summary 走 .running 分支），
        // 用户消息以 pending item 追加。
        #expect(vm.agentTurns.first?.record?.state == .completed)
        #expect(vm.agentTurns.last?.pendingAnchorMessageID == pendingUser.id)
        #expect(vm.agentTurns.first?.acceptsLiveActivity == false)
    }
}
