import Foundation
import KernelCore
import ProviderAgentLoop
import ProviderConversation
import ProviderLifecycleHooks
import ProviderMessage
import ProviderMessageSender
import Testing
@testable import PluginMessageSender

/// 覆盖 TestPlan「观察者 / 恢复 / 插件生命周期」章节：ID 12–14、ID 17。
@Suite("MessageSender 观察与恢复")
@MainActor
struct MessageSenderObservationTests {

    // MARK: - ID 12: isSending 观察者

    @Test("isSending 观察者仅在状态真实变化时触发")
    func sendingStateObserverFiresOnlyOnRealChanges() async throws {
        let fixture = SenderFixture()
        let conversationID = try fixture.conversations.createConversation(
            title: nil, projectPath: nil, providerID: nil, modelName: nil
        )
        var states: [Bool] = []
        let handle = fixture.sender.addSendingStateObserver { states.append($0) }
        defer { handle.cancel() }

        let result = try fixture.sender.commitUserMessage("hi", conversationID: conversationID)
        let commit = try #require(result)
        // 仅提交不改变 isSending。
        #expect(states.isEmpty)

        let turn = Task { await fixture.sender.startTurn(for: commit) }
        await waitUntil { fixture.sender.isSending }
        #expect(states == [true])

        // 同一状态重复赋值不应重复触发（由 resumeTurn 的 defer 覆盖）。
        fixture.sender.handleAgentLoopEvent(.completed(conversationID: conversationID, turnID: UUID()))
        await turn.value
        #expect(states == [true, false])
    }

    @Test("isSending 观察者 cancel 后不再收到回调")
    func sendingStateObserverStopsAfterCancel() async throws {
        let fixture = SenderFixture()
        let conversationID = try fixture.conversations.createConversation(
            title: nil, projectPath: nil, providerID: nil, modelName: nil
        )
        var states: [Bool] = []
        let handle = fixture.sender.addSendingStateObserver { states.append($0) }

        let result = try fixture.sender.commitUserMessage("hi", conversationID: conversationID)
        let commit = try #require(result)
        let turn = Task { await fixture.sender.startTurn(for: commit) }
        await waitUntil { fixture.sender.isSending }
        #expect(states == [true])

        handle.cancel()
        // 重复 cancel 安全。
        handle.cancel()

        fixture.sender.handleAgentLoopEvent(.completed(conversationID: conversationID, turnID: UUID()))
        await turn.value
        #expect(states == [true])
    }

    // MARK: - ID 13: 事件订阅令牌

    @Test("事件订阅令牌 cancel 后不再收到事件，重复 cancel 安全")
    func messageSenderObserverStopsAfterCancel() async throws {
        let fixture = SenderFixture()
        let conversationID = try fixture.conversations.createConversation(
            title: nil, projectPath: nil, providerID: nil, modelName: nil
        )
        var eventCount = 0
        let handle = fixture.sender.addMessageSenderObserver { _ in eventCount += 1 }

        _ = try fixture.sender.commitUserMessage("hi", conversationID: conversationID)
        #expect(eventCount == 0) // 首次提交不广播事件

        let handle2 = fixture.sender.addMessageSenderObserver { _ in eventCount += 1 }
        handle2.cancel()
        handle2.cancel()

        // 通过 resumeTurn 触发一次事件，确认已取消的订阅不再收到。
        _ = try? await fixture.sender.resumeTurn(
            in: conversationID,
            request: AgentTurnResumeRequest(suspensionID: "s-1", answer: "ok")
        )
        let eventsAfterResume = eventCount

        handle.cancel()
        _ = try? await fixture.sender.resumeTurn(
            in: conversationID,
            request: AgentTurnResumeRequest(suspensionID: "s-2", answer: "ok")
        )
        #expect(eventCount == eventsAfterResume)
    }

    // MARK: - ID 14: resumeTurn 分支

    @Test("resumeTurn 成功时广播 turnCompleted 并复位 isSending", arguments: [
        AgentLoopOutcome.completed,
        .suspended("ask-2"),
        .cancelled
    ])
    func resumeTurnSuccessBranches(outcome: AgentLoopOutcome) async throws {
        let fixture = SenderFixture()
        let conversationID = try fixture.conversations.createConversation(
            title: nil, projectPath: nil, providerID: nil, modelName: nil
        )
        fixture.agentLoop.resumeOutcome = outcome
        var events: [MessageSenderEvent] = []
        let observer = fixture.sender.addMessageSenderObserver { events.append($0) }
        defer { observer.cancel() }

        let result = try await fixture.sender.resumeTurn(
            in: conversationID,
            request: AgentTurnResumeRequest(suspensionID: "ask-1", answer: "yes")
        )

        #expect(result == outcome)
        #expect(events.count == 2)
        guard case .started = events[0] else {
            Issue.record("首个事件应为 .started，实际为 \(events[0])")
            return
        }
        guard case .turnCompleted(_, let completed) = events[1] else {
            Issue.record("次个事件应为 .turnCompleted，实际为 \(events[1])")
            return
        }
        #expect(completed == outcome)
        #expect(fixture.sender.isSending == false)
    }

    @Test("resumeTurn 失败时广播 turnFailed 并抛出原错误")
    func resumeTurnFailureBranch() async throws {
        let fixture = SenderFixture()
        let conversationID = try fixture.conversations.createConversation(
            title: nil, projectPath: nil, providerID: nil, modelName: nil
        )
        fixture.agentLoop.resumeError = StubAgentLoopError(reason: "boom")
        var failures: [String] = []
        let observer = fixture.sender.addMessageSenderObserver { event in
            if case .turnFailed(_, let reason) = event { failures.append(reason) }
        }
        defer { observer.cancel() }

        await #expect(throws: StubAgentLoopError.self) {
            try await fixture.sender.resumeTurn(
                in: conversationID,
                request: AgentTurnResumeRequest(suspensionID: "ask-1", answer: "yes")
            )
        }

        // 广播的 reason 取自 error.localizedDescription，包含原始原因文本。
        #expect(failures.count == 1)
        #expect(failures.first?.contains("boom") == true)
        #expect(fixture.sender.isSending == false)
    }

    // MARK: - ID 17: 插件 shutdown 拆除监听

    @Test("onShutdown 拆除 AgentLoop 监听，不再转发事件")
    func shutdownRemovesAgentLoopObserver() throws {
        let kernel = KernelCoreContainer()
        let conversations = DefaultConversationManager()
        try kernel.registerProvider((any ConversationManaging).self, conversations)
        let messages = DefaultMessageManager()
        try kernel.registerProvider((any MessageManaging).self, messages)
        let agentLoop = StubAgentLoop(messages: messages)
        try kernel.registerProvider((any AgentLoopProviding).self, agentLoop)

        let plugin = MessageSenderPlugin()
        try plugin.onBoot(kernel: kernel)
        #expect(agentLoop.observerCount == 1)

        let sender = try #require(kernel.resolveProvider((any MessageSendingProviding).self))
        var eventCount = 0
        let observer = sender.addMessageSenderObserver { _ in eventCount += 1 }
        defer { observer.cancel() }

        try plugin.onShutdown(kernel: kernel)
        #expect(agentLoop.observerCount == 0)

        // shutdown 后的 AgentLoop 事件不应再转发给 sender。
        agentLoop.notify(.completed(conversationID: UUID(), turnID: UUID()))
        #expect(eventCount == 0)
    }

    @Test("shutdown 后再次 shutdown 保持安全")
    func repeatedShutdownIsSafe() throws {
        let kernel = KernelCoreContainer()
        let messages = DefaultMessageManager()
        try kernel.registerProvider((any MessageManaging).self, messages)
        let agentLoop = StubAgentLoop(messages: messages)
        try kernel.registerProvider((any AgentLoopProviding).self, agentLoop)
        try kernel.registerProvider(
            (any ConversationManaging).self,
            DefaultConversationManager()
        )

        let plugin = MessageSenderPlugin()
        try plugin.onBoot(kernel: kernel)
        try plugin.onShutdown(kernel: kernel)
        try plugin.onShutdown(kernel: kernel)

        #expect(agentLoop.observerCount == 0)
    }
}
