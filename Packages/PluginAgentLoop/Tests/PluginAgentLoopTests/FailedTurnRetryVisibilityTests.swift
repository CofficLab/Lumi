import Testing
import Foundation
import KitLLM
@testable import PluginAgentLoop
import ProviderAgentLoop
import ProviderConversation
import ProviderMessage
import ProviderMessageStreaming
import ProviderLLMContext
import ProviderLLMManager
import ProviderToolManager

/// 回归测试：回合失败后「重试该回合」的入口判定必须仍然成立。
///
/// 背景：error 消息 header 上的重试按钮依赖
/// `state(for:) == .failed && currentTurnID(for:) == turnID`。
/// `TurnPhase.turnID` 对 `.failed` 返回 `nil`，若 `TurnRuntime.turnID` 直接透传它，
/// 回合一失败 `currentTurnID` 就变成 `nil`，按钮永久失效（点了没反应）。
/// `lastTurnID` 才是终态下仍然有效的回合身份，`retryTurn` 本身也正是用它校验。
@MainActor
private func makeFailedLoop(
    conversationID: UUID,
    failedTurnID: UUID,
    reason: String
) -> AgentLoopManager {
    let messages = DefaultMessageManager()
    let loop = AgentLoopManager(
        messages: messages,
        llmManager: DefaultLLMManager(),
        toolManager: DefaultToolManagerProviding(),
        streaming: DefaultMessageStreamingProviding(),
        conversations: DefaultConversationManager(),
        contextProvider: PassthroughLLMContextProvider(messages: messages)
    )
    // 走真实 reducer 路径，而不是手工拼装 runtime。
    let started = TurnReducer.reduce(TurnRuntime(), event: .startTurn(turnID: failedTurnID))
    let failed = TurnReducer.reduce(started.0, event: .llmFailed(reason: reason))
    loop.runtimes[conversationID] = failed.0
    return loop
}

@MainActor
@Test("回合失败后 currentTurnID 仍返回失败回合的 ID")
func failedTurnKeepsCurrentTurnID() {
    let conversationID = UUID()
    let failedTurnID = UUID()
    let loop = makeFailedLoop(
        conversationID: conversationID,
        failedTurnID: failedTurnID,
        reason: "network down"
    )

    #expect(loop.state(for: conversationID) == .failed)
    // 核心回归断言：修复前这里为 nil，导致重试按钮永久不可用。
    #expect(loop.currentTurnID(for: conversationID) == failedTurnID)
}

@MainActor
@Test("失败回合可重试：currentTurnID 与错误消息的 turnID 一致时判定成立")
func failedTurnIsRetryable() {
    let conversationID = UUID()
    let failedTurnID = UUID()
    let loop = makeFailedLoop(
        conversationID: conversationID,
        failedTurnID: failedTurnID,
        reason: "network down"
    )

    // 复刻 MessageRendererCapabilityAdapter.canRetryTurn 的判定。
    let canRetry = loop.state(for: conversationID) == .failed
        && loop.currentTurnID(for: conversationID) == failedTurnID
    #expect(canRetry)
}

@MainActor
@Test("过期回合不可重试：currentTurnID 已推进到新回合")
func staleTurnIsNotRetryable() {
    let conversationID = UUID()
    let staleTurnID = UUID()
    let loop = makeFailedLoop(
        conversationID: conversationID,
        failedTurnID: staleTurnID,
        reason: "network down"
    )

    // 用户随后发起了新回合，旧错误消息上的重试按钮不应再指向当前回合。
    let newTurnID = UUID()
    let started = TurnReducer.reduce(TurnRuntime(), event: .startTurn(turnID: newTurnID))
    loop.runtimes[conversationID] = started.0

    #expect(loop.currentTurnID(for: conversationID) == newTurnID)
    #expect(loop.currentTurnID(for: conversationID) != staleTurnID)
}

@MainActor
@Test("idle 会话没有当前回合，不可重试")
func idleConversationHasNoRetryableTurn() {
    let conversationID = UUID()
    let loop = makeFailedLoop(
        conversationID: conversationID,
        failedTurnID: UUID(),
        reason: "network down"
    )
    loop.runtimes[conversationID] = TurnRuntime()

    #expect(loop.state(for: conversationID) == .idle)
    #expect(loop.currentTurnID(for: conversationID) == nil)
}

@MainActor
@Test("终态 phase 同样保留回合身份，不影响 completed 回合的读取")
func completedTurnKeepsCurrentTurnID() {
    let conversationID = UUID()
    let turnID = UUID()
    let messages = DefaultMessageManager()
    let loop = AgentLoopManager(
        messages: messages,
        llmManager: DefaultLLMManager(),
        toolManager: DefaultToolManagerProviding(),
        streaming: DefaultMessageStreamingProviding(),
        conversations: DefaultConversationManager(),
        contextProvider: PassthroughLLMContextProvider(messages: messages)
    )

    let started = TurnReducer.reduce(TurnRuntime(), event: .startTurn(turnID: turnID))
    let completed = TurnReducer.reduce(
        started.0,
        event: .llmResponded(
            response: LLMResponse(content: "done", model: "m"),
            assistantMessageID: UUID()
        )
    )
    loop.runtimes[conversationID] = completed.0

    #expect(loop.state(for: conversationID) == .completed)
    #expect(loop.currentTurnID(for: conversationID) == turnID)
}

@MainActor
@Test("失败回合不接收新 Tool Job，终态回合身份不会让旧 Job 复活")
func terminalTurnDoesNotResurrectToolJobs() {
    let conversationID = UUID()
    let failedTurnID = UUID()
    let loop = makeFailedLoop(
        conversationID: conversationID,
        failedTurnID: failedTurnID,
        reason: "network down"
    )

    // registerToolJob / handleToolJobTerminal 用
    // `runtime.turnID == jobTurnID` 做归属校验，回合身份必须是失败的回合本身。
    let lateJobTurnID = UUID()
    #expect(loop.currentTurnID(for: conversationID) == failedTurnID)
    #expect(loop.currentTurnID(for: conversationID) != lateJobTurnID)
}