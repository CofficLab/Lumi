import Foundation
import ProviderAgentLoop
import ProviderConversation
import ProviderMessage
import Testing
@testable import PluginMessageSender

/// 覆盖「回合进行中再次发送」的守门逻辑。
///
/// ## 背景
///
/// `MessageSender` 用自己的私有账本（`currentTasks` / `pendingTurnStarts`）
/// 判断「这个会话是不是正忙着」：
///
/// ```swift
/// private func isSending(for conversationID: UUID) -> Bool {
///     currentTasks[conversationID] != nil || pendingTurnStarts.contains(conversationID)
/// }
/// ```
///
/// 账本为空 ⇒ 新消息**不入队**，直接写进消息时间线。
///
/// 但「会话忙不忙」的事实来源是 `AgentLoopProviding`（回合状态机），
/// 不是发送器的账本。两者的口径不一致时，**回合明明还在跑，新消息却直接
/// 落进了消息列表**，而不是进入待发队列。
///
/// ## 本套件覆盖的两条口径裂缝
///
/// 1. **回合挂起（suspended）**：`.suspended` 事件会结束发送器的回合跟踪任务，
///    账本被清空；但回合本身**没结束**，仍在等用户回答/授权。
/// 2. **回合由外部路径拉起**（ACP 托管、自动重试、Goal 续跑）：
///    发送器从头到尾没有账本条目，却有一个活回合在跑。
///
/// 两种情况下 `canStop == true`（界面显示停止按钮，说明会话确实忙），
/// 而发送器却认为空闲——用户按回车即可把新消息直接写进消息列表。
@Suite("MessageSender 回合中再发送的守门")
@MainActor
struct MessageSenderBusyGateTests {

    // MARK: - 裂缝 1：回合挂起

    /// 回合挂在等用户回答时，再次发送应进入待发队列，而不是直接落入消息列表。
    ///
    /// - Important: `.suspended` 事件**必须**被接受，否则账本不会被清空、
    ///   本用例就测不到裂缝。桩需同时满足状态、turnID、suspensionID 三项校验
    ///   （见 `MessageSender.handleAgentLoopEvent` 的 suspended 分支）。
    @Test("回合挂起期间再次发送应进入待发队列")
    func suspendedTurnQueuesNextMessage() async throws {
        let fixture = SenderFixture()
        let conversationID = try fixture.conversations.createConversation(
            title: nil, projectPath: nil, providerID: nil, modelName: nil
        )

        // 第一条消息正常发出并开启回合跟踪。
        let firstCommit = try #require(
            try fixture.sender.commitUserMessage("first", conversationID: conversationID)
        )
        let turn = Task { await fixture.sender.startTurn(for: firstCommit) }
        await waitUntil { fixture.sender.isSending }

        // 回合挂起：AgentLoop 仍在等用户，但发送器的跟踪任务已经结束。
        let turnID = UUID()
        let suspension = AgentLoopSuspension(
            suspensionID: "userInput:ask-1",
            conversationID: conversationID,
            toolCallID: "ask-1",
            kind: "userInput",
            payload: "{}"
        )
        fixture.agentLoop.currentState = .suspended
        fixture.agentLoop.activeTurnID = turnID
        fixture.agentLoop.activeSuspension = suspension
        fixture.sender.handleAgentLoopEvent(.suspended(
            conversationID: conversationID,
            turnID: turnID,
            suspension: suspension
        ))
        await turn.value

        // 回合仍活着：AgentLoop 认为它没结束，界面也因此显示停止按钮。
        #expect(fixture.agentLoop.state(for: conversationID) == .suspended)

        // 挂起期间再次发送。
        let secondCommit = try fixture.sender.commitUserMessage(
            "second",
            conversationID: conversationID
        )

        // 期望：会话仍忙 → 新消息进待发队列，不进消息列表。
        #expect(
            secondCommit?.wasQueued == true,
            "回合仍处于挂起态，新消息应当入队而不是直接落入消息列表"
        )
        #expect(
            fixture.sender.pendingMessages(for: conversationID).map(\.content) == ["second"],
            "新消息应出现在待发队列中"
        )
        #expect(
            fixture.messages.messages(for: conversationID).map(\.content) == ["first"],
            "回合进行中，新消息不应直接写入消息列表"
        )
    }

    /// 挂起后账本被清空，`isSending` 归零 —— 这正是「界面说忙、发送器说闲」的裂缝。
    @Test("回合挂起后发送器不再认为会话在发送")
    func suspendedTurnClearsSenderBusyFlag() async throws {
        let fixture = SenderFixture()
        let conversationID = try fixture.conversations.createConversation(
            title: nil, projectPath: nil, providerID: nil, modelName: nil
        )
        let firstCommit = try #require(
            try fixture.sender.commitUserMessage("first", conversationID: conversationID)
        )
        let turn = Task { await fixture.sender.startTurn(for: firstCommit) }
        await waitUntil { fixture.sender.isSending }

        let turnID = UUID()
        let suspension = AgentLoopSuspension(
            suspensionID: "userInput:ask-1",
            conversationID: conversationID,
            toolCallID: "ask-1",
            kind: "userInput",
            payload: "{}"
        )
        fixture.agentLoop.currentState = .suspended
        fixture.agentLoop.activeTurnID = turnID
        fixture.agentLoop.activeSuspension = suspension
        fixture.sender.handleAgentLoopEvent(.suspended(
            conversationID: conversationID,
            turnID: turnID,
            suspension: suspension
        ))
        await turn.value

        // 发送器账本已清空。
        #expect(fixture.sender.isSending == false)
        // 但会话客观上仍在忙（AgentLoop 回合没结束）。
        #expect(fixture.agentLoop.state(for: conversationID) == .suspended)
    }

    // MARK: - 裂缝 2：回合由外部路径拉起

    /// 回合由外部路径（ACP 托管 / 自动重试 / Goal 续跑）拉起时，
    /// 发送器没有账本条目，却必须承认「会话在忙」。
    @Test("外部拉起的回合期间再次发送应进入待发队列")
    func externallyDrivenTurnQueuesNextMessage() throws {
        let fixture = SenderFixture()
        let conversationID = try fixture.conversations.createConversation(
            title: nil, projectPath: nil, providerID: nil, modelName: nil
        )

        // 模拟 ACP 托管 / 自动重试拉起的回合：
        // AgentLoop 在跑，但发送器从未 startTurn 过，没有自己的账本。
        fixture.agentLoop.currentState = .running

        let commit = try fixture.sender.commitUserMessage("hello", conversationID: conversationID)

        #expect(
            commit?.wasQueued == true,
            "AgentLoop 已有活回合时，新消息应当入队而不是直接落入消息列表"
        )
        #expect(
            fixture.sender.pendingMessages(for: conversationID).map(\.content) == ["hello"],
            "新消息应出现在待发队列中"
        )
        #expect(
            fixture.messages.messages(for: conversationID).isEmpty,
            "回合进行中，新消息不应直接写入消息列表"
        )
    }

    // MARK: - ask_user 例外

    /// `ask_user` 挂起期间的新消息应当**直接落库**，而不是入队。
    ///
    /// `ask_user` 只是模型向用户提问，用户可以用继续聊天来跳过它：
    /// `PluginAgentLoop` 的 `MessageObserver` 会检测到该挂起点，用固定的
    /// 「跳过问题」答案恢复原回合，并保留这条新消息。
    @Test("ask_user 挂起期间的新消息直接落库，不入队")
    func askUserSuspensionLetsNewMessageLandImmediately() throws {
        let fixture = SenderFixture()
        let conversationID = try fixture.conversations.createConversation(
            title: nil, projectPath: nil, providerID: nil, modelName: nil
        )

        // AgentLoop 停在 ask_user 提问上。
        fixture.agentLoop.currentState = .suspended
        fixture.agentLoop.activeTurnID = UUID()
        fixture.agentLoop.activeSuspension = Self.askUserSuspension(conversationID: conversationID)

        let commit = try fixture.sender.commitUserMessage("skip it", conversationID: conversationID)

        #expect(
            commit?.wasQueued == false,
            "ask_user 可以被继续聊天跳过，新消息不应入队"
        )
        #expect(
            fixture.messages.messages(for: conversationID).map(\.content) == ["skip it"],
            "新消息应当直接写入消息列表"
        )
        #expect(fixture.sender.pendingMessages(for: conversationID).isEmpty)
    }

    /// 工具授权挂起期间的新消息必须**入队**。
    ///
    /// 授权是安全闸门，与 `ask_user` 相反：用户的新消息不能替代授权决定。
    @Test("授权挂起期间的新消息进入待发队列")
    func authorizationSuspensionQueuesNewMessage() throws {
        let fixture = SenderFixture()
        let conversationID = try fixture.conversations.createConversation(
            title: nil, projectPath: nil, providerID: nil, modelName: nil
        )

        fixture.agentLoop.currentState = .suspended
        fixture.agentLoop.activeTurnID = UUID()
        fixture.agentLoop.activeSuspension = Self.authorizationSuspension(conversationID: conversationID)

        let commit = try fixture.sender.commitUserMessage("hello", conversationID: conversationID)

        #expect(
            commit?.wasQueued == true,
            "授权挂起时新消息必须排队，不能替代授权决定"
        )
        #expect(
            fixture.messages.messages(for: conversationID).isEmpty,
            "授权挂起期间新消息不应直接写入消息列表"
        )
    }

    // MARK: - 终态排空

    /// 回合到达终态后，队列应当排空。
    @Test("回合到达终态后队列排空")
    func terminalOutcomeDrainsQueue() throws {
        let fixture = SenderFixture()
        let conversationID = try fixture.conversations.createConversation(
            title: nil, projectPath: nil, providerID: nil, modelName: nil
        )

        // 外部回合在跑 → 消息入队。
        fixture.agentLoop.currentState = .running
        _ = try fixture.sender.commitUserMessage("first", conversationID: conversationID)
        #expect(fixture.sender.pendingMessages(for: conversationID).count == 1)

        // 回合到达终态 → 队列排空。
        fixture.agentLoop.currentState = .completed
        fixture.sender.handleAgentLoopEvent(.completed(conversationID: conversationID, turnID: UUID()))

        #expect(
            fixture.sender.pendingMessages(for: conversationID).isEmpty,
            "终态事件应触发队列排空"
        )
        #expect(
            fixture.messages.messages(for: conversationID).map(\.content) == ["first"],
            "排空时队列内容应当落库"
        )
    }

    /// 回合挂起**不是**终态：队列不能排空。
    @Test("回合挂起时队列不排空")
    func suspendedOutcomeDoesNotDrainQueue() throws {
        let fixture = SenderFixture()
        let conversationID = try fixture.conversations.createConversation(
            title: nil, projectPath: nil, providerID: nil, modelName: nil
        )

        // 授权挂起 → 消息入队。
        fixture.agentLoop.currentState = .suspended
        fixture.agentLoop.activeTurnID = UUID()
        fixture.agentLoop.activeSuspension = Self.authorizationSuspension(conversationID: conversationID)
        _ = try fixture.sender.commitUserMessage("first", conversationID: conversationID)
        #expect(fixture.sender.pendingMessages(for: conversationID).count == 1)

        // 挂起事件到达：队列必须继续等。
        fixture.sender.handleAgentLoopEvent(.suspended(
            conversationID: conversationID,
            turnID: try #require(fixture.agentLoop.activeTurnID),
            suspension: try #require(fixture.agentLoop.activeSuspension)
        ))

        #expect(
            fixture.sender.pendingMessages(for: conversationID).count == 1,
            "挂起不是终态，队列不应排空"
        )
        #expect(
            fixture.messages.messages(for: conversationID).isEmpty,
            "挂起期间排队消息不应落库"
        )
    }

    /// `resumeTurn` 到达终态后，队列应当排空。
    ///
    /// 恢复路径没有回合跟踪任务，队列没人排空——必须由 `resumeTurn` 补上。
    @Test("resumeTurn 完成后队列排空")
    func resumeTurnDrainsQueueOnTerminalOutcome() async throws {
        let fixture = SenderFixture()
        let conversationID = try fixture.conversations.createConversation(
            title: nil, projectPath: nil, providerID: nil, modelName: nil
        )

        // 授权挂起 → 消息入队。
        fixture.agentLoop.currentState = .suspended
        fixture.agentLoop.activeTurnID = UUID()
        fixture.agentLoop.activeSuspension = Self.authorizationSuspension(conversationID: conversationID)
        _ = try fixture.sender.commitUserMessage("first", conversationID: conversationID)
        #expect(fixture.sender.pendingMessages(for: conversationID).count == 1)

        // 恢复后回合完成。
        fixture.agentLoop.currentState = .completed
        fixture.agentLoop.resumeOutcome = .completed
        _ = try await fixture.sender.resumeTurn(
            in: conversationID,
            request: AgentTurnResumeRequest(
                suspensionID: "userInput:approval-1",
                answer: "allow"
            )
        )

        #expect(
            fixture.sender.pendingMessages(for: conversationID).isEmpty,
            "resumeTurn 到达终态后应排空队列"
        )
        #expect(
            fixture.messages.messages(for: conversationID).map(\.content) == ["first"],
            "排空时队列内容应当落库"
        )
    }

    // MARK: - 正常路径未被破坏

    /// 会话空闲时发送仍然直接落库，不入队。
    ///
    /// 上面的守门若改成「一律入队」，这条会挂——它锁住修复不能矫枉过正。
    @Test("会话空闲时发送仍然直接落库")
    func idleConversationSendsImmediately() throws {
        let fixture = SenderFixture()
        let conversationID = try fixture.conversations.createConversation(
            title: nil, projectPath: nil, providerID: nil, modelName: nil
        )

        let commit = try fixture.sender.commitUserMessage("hello", conversationID: conversationID)

        #expect(commit?.wasQueued == false)
        #expect(fixture.messages.messages(for: conversationID).map(\.content) == ["hello"])
        #expect(fixture.sender.pendingMessages(for: conversationID).isEmpty)
    }

    // MARK: - Helpers

    /// `ask_user` 提问的挂起点。
    ///
    /// payload 结构与 `AskUserTool` 实际写出的 `AskUserPendingResponse` 一致：
    /// `toolCallId == "ask_user"` 且 `question` 非空。
    private static func askUserSuspension(conversationID: UUID) -> AgentLoopSuspension {
        AgentLoopSuspension(
            suspensionID: "userInput:ask-1",
            conversationID: conversationID,
            toolCallID: "ask-1",
            kind: "userInput",
            payload: #"{"toolCallId":"ask_user","question":"继续吗？","options":[],"mode":"yes_no"}"#
        )
    }

    /// 工具授权的挂起点。
    ///
    /// payload 结构与 `ToolManager` 写出的授权载荷一致：`toolCallId` 以
    /// `approval:` 开头、`kind == "permission"`。
    private static func authorizationSuspension(conversationID: UUID) -> AgentLoopSuspension {
        AgentLoopSuspension(
            suspensionID: "userInput:approval-1",
            conversationID: conversationID,
            toolCallID: "approval-1",
            kind: "permission",
            payload: #"{"toolCallID":"approval:approval-1","kind":"permission","question":"是否允许执行？","options":["允许","拒绝"],"mode":"yes_no"}"#
        )
    }
}
