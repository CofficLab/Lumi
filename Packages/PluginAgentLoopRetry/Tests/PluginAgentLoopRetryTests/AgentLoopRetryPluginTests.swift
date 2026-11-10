import Foundation
import Testing
@testable import PluginAgentLoopRetry
import ProviderAgentLoop
import ProviderConversation
import ProviderLifecycleHooks
import ProviderMessage

@MainActor
struct AgentLoopRetryPluginTests {
    @Test("可重试失败最多自动重试三次并记录完整时间线")
    func retriesTransientFailureThreeTimes() async {
        let conversationID = UUID()
        let messages = DefaultMessageManager()
        let agentLoop = TestAgentLoop(outcomes: [
            .failed("network"),
            .failed("network"),
            .failed("network"),
        ])
        let coordinator = AgentLoopRetryCoordinator(
            loop: AgentLoopRetryCapabilityAdapter(agentLoop: agentLoop),
            messages: AgentLoopRetryMessageCapabilityAdapter(messages: messages),
            maxAttempts: 3
        )

        agentLoop.failure = AgentLoopFailure(
            kind: .network,
            message: "连接被重置",
            providerID: "openai",
            modelName: "gpt-5",
            httpStatusCode: 503
        )
        agentLoop.emit(.failed(conversationID: conversationID, turnID: UUID(), reason: "连接被重置"))
        await yieldUntil { agentLoop.retryCalls.count == 3 }

        let retryMessages = messages.messages(for: conversationID)
            .filter(MessageTimelineEvent.isAgentLoopRetry)
        #expect(agentLoop.retryCalls.count == 3)
        #expect(retryMessages.count == 3)
        #expect(retryMessages.compactMap {
            MessageTimelineEvent.integerMetadata(
                MessageTimelineEvent.agentLoopRetryAttemptKey,
                from: $0
            )
        } == [1, 2, 3])
        #expect(retryMessages.allSatisfy { $0.role == .system })
        #expect(retryMessages[0].metadata[MessageTimelineEvent.agentLoopRetryProviderIDKey] == "openai")
        #expect(retryMessages[0].metadata[MessageTimelineEvent.agentLoopRetryModelNameKey] == "gpt-5")
        #expect(retryMessages[0].metadata[MessageTimelineEvent.agentLoopRetryHTTPStatusCodeKey] == "503")

        coordinator.cancel()
    }

    @Test("服务端给出 Retry-After 时，重启回合前先等待")
    func waitsBeforeRetryWhenServerAdvises() async {
        let conversationID = UUID()
        let messages = DefaultMessageManager()
        let agentLoop = TestAgentLoop(outcomes: [.failed("network")])
        // 由测试显式驱动失败序列，避免 retryTurn 内部的终态事件重复计数。
        agentLoop.emitsTerminalEvent = false
        let log = EventLog()
        agentLoop.eventLog = log

        let coordinator = AgentLoopRetryCoordinator(
            loop: AgentLoopRetryCapabilityAdapter(agentLoop: agentLoop),
            messages: AgentLoopRetryMessageCapabilityAdapter(messages: messages),
            maxAttempts: 3,
            sleeper: { seconds in
                await log.append("wait:\(Int(seconds.rounded()))")
            }
        )

        agentLoop.failure = AgentLoopFailure(
            kind: .server,
            message: "服务集群负载较高",
            httpStatusCode: 529,
            retryAfterSeconds: 30
        )
        agentLoop.emit(.failed(conversationID: conversationID, turnID: UUID(), reason: "服务集群负载较高"))
        await yieldUntil { agentLoop.retryCalls.count == 1 }

        let events = await log.events
        #expect(
            events == ["wait:30", "retry"],
            "必须先等待服务端建议的 30s，再重启回合"
        )
        #expect(agentLoop.retryCalls.count == 1)

        // 时间线提示在等待之前就已写入，用户能看到「正在重试」。
        let retryMessages = messages.messages(for: conversationID)
            .filter(MessageTimelineEvent.isAgentLoopRetry)
        #expect(retryMessages.count == 1)
        #expect(retryMessages[0].metadata[MessageTimelineEvent.agentLoopRetryRetryAfterKey] == "30")

        coordinator.cancel()
    }

    @Test("没有服务端建议时不额外等待")
    func doesNotWaitWithoutServerAdvice() async {
        let conversationID = UUID()
        let messages = DefaultMessageManager()
        let agentLoop = TestAgentLoop(outcomes: [.failed("network")])
        agentLoop.emitsTerminalEvent = false
        let log = EventLog()
        agentLoop.eventLog = log

        let coordinator = AgentLoopRetryCoordinator(
            loop: AgentLoopRetryCapabilityAdapter(agentLoop: agentLoop),
            messages: AgentLoopRetryMessageCapabilityAdapter(messages: messages),
            maxAttempts: 3,
            sleeper: { seconds in
                await log.append("wait:\(Int(seconds.rounded()))")
            }
        )

        agentLoop.failure = AgentLoopFailure(
            kind: .network,
            message: "连接被重置",
            httpStatusCode: 503
        )
        agentLoop.emit(.failed(conversationID: conversationID, turnID: UUID(), reason: "连接被重置"))
        await yieldUntil { agentLoop.retryCalls.count == 1 }

        let events = await log.events
        #expect(events == ["retry"], "无服务端建议时不得引入等待")
        coordinator.cancel()
    }

    @Test("不可重试失败不会启动重试")
    func doesNotRetryNonRetryableFailure() async {
        let conversationID = UUID()
        let messages = DefaultMessageManager()
        let agentLoop = TestAgentLoop()
        let coordinator = AgentLoopRetryCoordinator(
            loop: AgentLoopRetryCapabilityAdapter(agentLoop: agentLoop),
            messages: AgentLoopRetryMessageCapabilityAdapter(messages: messages),
            maxAttempts: 3
        )

        agentLoop.failure = AgentLoopFailure(
            kind: .authentication,
            message: "API key missing"
        )
        agentLoop.emit(.failed(conversationID: conversationID, turnID: UUID(), reason: "API key missing"))
        await Task.yield()

        #expect(agentLoop.retryCalls.isEmpty)
        #expect(messages.messages(for: conversationID).isEmpty)
        coordinator.cancel()
    }

    @Test("完成后新失败链从第一次重试重新计数")
    func resetsAfterSuccessfulRetry() async {
        let conversationID = UUID()
        let messages = DefaultMessageManager()
        let agentLoop = TestAgentLoop(outcomes: [.completed, .completed])
        let coordinator = AgentLoopRetryCoordinator(
            loop: AgentLoopRetryCapabilityAdapter(agentLoop: agentLoop),
            messages: AgentLoopRetryMessageCapabilityAdapter(messages: messages),
            maxAttempts: 3
        )
        let failure = AgentLoopFailure(kind: .network, message: "暂时不可用")
        agentLoop.failure = failure

        agentLoop.emit(.failed(conversationID: conversationID, turnID: UUID(), reason: failure.message))
        await yieldUntil { agentLoop.retryCalls.count == 1 }
        agentLoop.emit(.failed(conversationID: conversationID, turnID: UUID(), reason: failure.message))
        await yieldUntil { agentLoop.retryCalls.count == 2 }

        let attempts = messages.messages(for: conversationID)
            .filter(MessageTimelineEvent.isAgentLoopRetry)
            .compactMap {
                MessageTimelineEvent.integerMetadata(
                    MessageTimelineEvent.agentLoopRetryAttemptKey,
                    from: $0
                )
            }
        #expect(attempts == [1, 1])
        coordinator.cancel()
    }

    @Test("成功返回工具调用后重试预算回到满额")
    func resetsBudgetAfterSuccessfulLLMResponse() async {
        let conversationID = UUID()
        let messages = DefaultMessageManager()
        let agentLoop = TestAgentLoop(outcomes: [.failed("empty")])
        // 由测试显式驱动失败序列，避免 retryTurn 内部的终态事件重复计数。
        agentLoop.emitsTerminalEvent = false
        let coordinator = AgentLoopRetryCoordinator(
            loop: AgentLoopRetryCapabilityAdapter(agentLoop: agentLoop),
            messages: AgentLoopRetryMessageCapabilityAdapter(messages: messages),
            maxAttempts: 3
        )
        let failure = AgentLoopFailure(kind: .emptyResponse, message: "模型返回空响应")
        agentLoop.failure = failure

        // 连续两次失败：消耗 1、2 次预算。
        for expected in 1...2 {
            agentLoop.emit(.failed(conversationID: conversationID, turnID: UUID(), reason: failure.message))
            await yieldUntil { agentLoop.retryCalls.count == expected }
        }

        // LLM 成功返回过一次工具调用：回合仍在进行，但失败不再背靠背。
        agentLoop.emit(.toolCallsReceived(
            conversationID: conversationID,
            turnID: UUID(),
            assistantMessageID: UUID(),
            toolCalls: []
        ))

        // 预算回到满额，之后两次失败各自从 1 重新计费。
        for expected in 3...4 {
            agentLoop.emit(.failed(conversationID: conversationID, turnID: UUID(), reason: failure.message))
            await yieldUntil { agentLoop.retryCalls.count == expected }
        }

        let attempts = messages.messages(for: conversationID)
            .filter(MessageTimelineEvent.isAgentLoopRetry)
            .compactMap {
                MessageTimelineEvent.integerMetadata(
                    MessageTimelineEvent.agentLoopRetryAttemptKey,
                    from: $0
                )
            }
        #expect(attempts == [1, 2, 1, 2])
        coordinator.cancel()
    }

    @Test("连续失败耗尽预算后不再重试")
    func stopsAfterConsecutiveFailuresExhaustBudget() async {
        let conversationID = UUID()
        let messages = DefaultMessageManager()
        let agentLoop = TestAgentLoop(outcomes: [.failed("empty")])
        agentLoop.emitsTerminalEvent = false
        let coordinator = AgentLoopRetryCoordinator(
            loop: AgentLoopRetryCapabilityAdapter(agentLoop: agentLoop),
            messages: AgentLoopRetryMessageCapabilityAdapter(messages: messages),
            maxAttempts: 3
        )
        let failure = AgentLoopFailure(kind: .emptyResponse, message: "模型返回空响应")
        agentLoop.failure = failure

        for expected in 1...3 {
            agentLoop.emit(.failed(conversationID: conversationID, turnID: UUID(), reason: failure.message))
            await yieldUntil { agentLoop.retryCalls.count == expected }
        }
        agentLoop.emit(.failed(conversationID: conversationID, turnID: UUID(), reason: failure.message))
        await Task.yield()

        #expect(agentLoop.retryCalls.count == 3)

        let attempts = messages.messages(for: conversationID)
            .filter(MessageTimelineEvent.isAgentLoopRetry)
            .compactMap {
                MessageTimelineEvent.integerMetadata(
                    MessageTimelineEvent.agentLoopRetryAttemptKey,
                    from: $0
                )
            }
        #expect(attempts == [1, 2, 3])
        coordinator.cancel()
    }

    @Test("调度与放弃重试时发布生命周期事件")
    func publishesRetryLifecycleEvents() async {
        let conversationID = UUID()
        let messages = DefaultMessageManager()
        let agentLoop = TestAgentLoop(outcomes: [.failed("network")])
        agentLoop.emitsTerminalEvent = false
        var events: [AgentLoopRetryLifecycleEvent] = []
        let coordinator = AgentLoopRetryCoordinator(
            loop: AgentLoopRetryCapabilityAdapter(agentLoop: agentLoop),
            messages: AgentLoopRetryMessageCapabilityAdapter(messages: messages),
            maxAttempts: 1,
            onLifecycleEvent: { events.append($0) }
        )
        let failure = AgentLoopFailure(kind: .network, message: "连接被重置")
        agentLoop.failure = failure

        agentLoop.emit(.failed(conversationID: conversationID, turnID: UUID(), reason: failure.message))
        #expect(events == [.scheduled(conversationID: conversationID, attempt: 1)])
        #expect(coordinator.isRetrying(conversationID: conversationID))
        await yieldUntil { agentLoop.retryCalls.count == 1 }

        // 重试再次失败且预算已耗尽：必须发布放弃事件，否则等待重试的
        // 上层（如 ACP）会永远停在未收尾状态。
        agentLoop.emit(.failed(conversationID: conversationID, turnID: UUID(), reason: failure.message))
        #expect(events.count == 2)
        #expect(events.last == .gaveUp(conversationID: conversationID, reason: "连接被重置"))
        #expect(!coordinator.isRetrying(conversationID: conversationID))

        coordinator.cancel()
    }

    @Test("退避等待期间删除会话会取消延迟重试")
    func deletionDuringBackoffCancelsRetry() async throws {
        let conversations = DefaultConversationManager()
        let conversationID = try conversations.createConversation(
            title: nil,
            projectPath: nil,
            providerID: nil,
            modelName: nil
        )
        let messages = DefaultMessageManager()
        let agentLoop = TestAgentLoop(outcomes: [.failed("network")])
        agentLoop.emitsTerminalEvent = false
        let gate = SleepGate()
        let coordinator = AgentLoopRetryCoordinator(
            loop: AgentLoopRetryCapabilityAdapter(agentLoop: agentLoop, conversations: conversations),
            messages: AgentLoopRetryMessageCapabilityAdapter(messages: messages),
            maxAttempts: 3,
            sleeper: { _ in
                await withTaskCancellationHandler {
                    await gate.wait()
                } onCancel: {
                    Task { await gate.markCancelled() }
                }
                if await gate.wasCancelled {
                    throw CancellationError()
                }
            }
        )

        agentLoop.failure = AgentLoopFailure(
            kind: .server,
            message: "服务集群负载较高",
            httpStatusCode: 529,
            retryAfterSeconds: 60
        )
        agentLoop.emit(.failed(conversationID: conversationID, turnID: UUID(), reason: "服务集群负载较高"))
        #expect(await gate.waitUntilEntered())

        // 退避期间用户删除会话：睡眠任务必须被取消，且不能再启动回合。
        conversations.deleteConversation(id: conversationID)
        try? await Task.sleep(for: .milliseconds(50))
        await gate.release()
        try? await Task.sleep(for: .milliseconds(50))

        #expect(agentLoop.retryCalls.isEmpty)
        #expect(await gate.wasCancelled, "删除会话必须取消退避任务")
        coordinator.cancel()
    }

    @Test("退避结束时会话已被删除则不重启回合")
    func doesNotRetryConversationDeletedDuringBackoff() async {
        let conversationID = UUID()
        let messages = DefaultMessageManager()
        let capability = TestRetryCapability()
        capability.failure = AgentLoopFailure(
            kind: .server,
            message: "服务集群负载较高",
            httpStatusCode: 529,
            retryAfterSeconds: 30
        )
        let gate = SleepGate()
        let coordinator = AgentLoopRetryCoordinator(
            loop: capability,
            messages: AgentLoopRetryMessageCapabilityAdapter(messages: messages),
            maxAttempts: 3,
            sleeper: { _ in await gate.wait() }
        )

        capability.emit(.failed(conversationID: conversationID, turnID: UUID()))
        #expect(await gate.waitUntilEntered())

        // 删除事件没有送达协调器时，重试前仍要自行确认会话存在。
        capability.exists = false
        await gate.release()
        try? await Task.sleep(for: .milliseconds(50))

        #expect(capability.retryCalls.isEmpty, "已删除的会话不能启动新回合")
        coordinator.cancel()
    }
}

@MainActor
private final class TestAgentLoop: AgentLoopProviding {
    struct RetryCall {
        let conversationID: UUID
        let failedTurnID: UUID
    }

    var failure: AgentLoopFailure?
    /// 每次 retryTurn 返回的终态。用尽后重复最后一项，而不是回退到
    /// `.completed`，否则测试桩会自己制造一次成功并让计数归零。
    var outcomes: [AgentLoopOutcome]
    /// 可选的事件日志：用于断言「先等待、后重启回合」的时序。
    var eventLog: EventLog?
    /// 由测试显式驱动终态事件时置为 false，避免 retryTurn 内部的终态事件
    /// 与测试手动 emit 的事件叠加，导致重试次数重复计费。
    var emitsTerminalEvent = true
    private var observers: [UUID: (AgentLoopEvent) -> Void] = [:]
    private(set) var retryCalls: [RetryCall] = []
    private var stateValue: AgentLoopState = .failed

    init(outcomes: [AgentLoopOutcome] = [.failed("network")]) {
        self.outcomes = outcomes
    }

    @discardableResult
    func addAgentLoopObserver(_ callback: @escaping (AgentLoopEvent) -> Void) -> any AgentLoopObserverHandle {
        let id = UUID()
        observers[id] = callback
        return Handle { [weak self] in
            self?.observers.removeValue(forKey: id)
        }
    }

    func runTurn(in conversationID: UUID) async throws -> AgentLoopOutcome { .completed }

    func resumeTurn(in conversationID: UUID, request: AgentTurnResumeRequest) async throws -> AgentLoopOutcome {
        .completed
    }

    func cancelTurn(in conversationID: UUID) {
        stateValue = .cancelled
        emit(.cancelled(conversationID: conversationID, turnID: nil))
    }

    func state(for conversationID: UUID) -> AgentLoopState { stateValue }
    func suspension(for conversationID: UUID) -> AgentLoopSuspension? { nil }
    func lastFailure(for conversationID: UUID) -> AgentLoopFailure? { failure }
    func isRunning(for conversationID: UUID) -> Bool { stateValue == .running }
    func currentTurnID(for conversationID: UUID) -> UUID? { nil }
    func setLifecycleHooks(_ hooks: (any LifecycleHooksProviding)?) {}

    func retryTurn(in conversationID: UUID, after failedTurnID: UUID) async throws -> AgentLoopOutcome {
        retryCalls.append(RetryCall(conversationID: conversationID, failedTurnID: failedTurnID))
        await eventLog?.append("retry")
        let turnID = UUID()
        stateValue = .running
        emit(.started(conversationID: conversationID, turnID: turnID))
        // 用尽后重复最后一个终态：桩不得自行制造成功。
        let outcome = outcomes.count > 1 ? outcomes.removeFirst() : (outcomes.first ?? .failed("empty"))
        guard emitsTerminalEvent else {
            stateValue = .failed
            return outcome
        }
        switch outcome {
        case .completed:
            stateValue = .completed
            emit(.completed(conversationID: conversationID, turnID: turnID))
        case .failed(let reason):
            stateValue = .failed
            emit(.failed(conversationID: conversationID, turnID: turnID, reason: reason))
        case .cancelled:
            stateValue = .cancelled
            emit(.cancelled(conversationID: conversationID, turnID: turnID))
        case .suspended:
            stateValue = .suspended
            emit(.suspended(
                conversationID: conversationID,
                turnID: turnID,
                suspension: AgentLoopSuspension(
                    suspensionID: "test",
                    conversationID: conversationID,
                    kind: "test",
                    payload: "{}"
                )
            ))
        }
        return outcome
    }

    func emit(_ event: AgentLoopEvent) {
        if case .failed = event {
            stateValue = .failed
        }
        for observer in observers.values {
            observer(event)
        }
    }

    private final class Handle: AgentLoopObserverHandle {
        private let cancellation: () -> Void

        init(_ cancellation: @escaping () -> Void) {
            self.cancellation = cancellation
        }

        func cancel() {
            cancellation()
        }
    }
}

/// 可被测试放行或标记取消的睡眠门闩，用来把协调器稳定地停在退避阶段。
private actor SleepGate {
    private(set) var entered = false
    private(set) var wasCancelled = false
    private var continuation: CheckedContinuation<Void, Never>?

    func wait() async {
        entered = true
        if wasCancelled { return }
        await withCheckedContinuation { continuation = $0 }
    }

    func markCancelled() {
        wasCancelled = true
        resume()
    }

    func release() {
        resume()
    }

    func waitUntilEntered(timeout: Duration = .seconds(1)) async -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while clock.now < deadline {
            if entered { return true }
            try? await Task.sleep(for: .milliseconds(5))
        }
        return entered
    }

    private func resume() {
        continuation?.resume()
        continuation = nil
    }
}

/// 只实现协调器所需能力的测试替身：可以单独改动会话存在性而不发删除事件。
@MainActor
private final class TestRetryCapability: AgentLoopRetryCapability {
    var failure: AgentLoopFailure?
    var state: AgentLoopRetryTurnState = .failed
    var exists = true
    private var turnObservers: [UUID: (AgentLoopRetryEvent) -> Void] = [:]
    private var deletionObservers: [UUID: (UUID) -> Void] = [:]
    private(set) var retryCalls: [UUID] = []

    func addTurnObserver(
        _ callback: @escaping (AgentLoopRetryEvent) -> Void
    ) -> any AgentLoopRetryObserverHandle {
        let id = UUID()
        turnObservers[id] = callback
        return TestObserverHandle { [weak self] in
            self?.turnObservers.removeValue(forKey: id)
        }
    }

    func addConversationDeletionObserver(
        _ callback: @escaping (UUID) -> Void
    ) -> any AgentLoopRetryObserverHandle {
        let id = UUID()
        deletionObservers[id] = callback
        return TestObserverHandle { [weak self] in
            self?.deletionObservers.removeValue(forKey: id)
        }
    }

    func lastFailure(for conversationID: UUID) -> AgentLoopFailure? {
        failure
    }

    func turnState(for conversationID: UUID) -> AgentLoopRetryTurnState {
        state
    }

    func conversationExists(for conversationID: UUID) -> Bool {
        exists
    }

    func retryTurn(in conversationID: UUID, after failedTurnID: UUID) async throws -> AgentLoopOutcome {
        retryCalls.append(conversationID)
        return .completed
    }

    func emit(_ event: AgentLoopRetryEvent) {
        if case .failed = event {
            state = .failed
        }
        for observer in turnObservers.values {
            observer(event)
        }
    }
}

@MainActor
private final class TestObserverHandle: AgentLoopRetryObserverHandle {
    private let cancellation: () -> Void

    init(_ cancellation: @escaping () -> Void) {
        self.cancellation = cancellation
    }

    func cancel() {
        cancellation()
    }
}

@MainActor
private func yieldUntil(
    _ condition: @escaping @MainActor () -> Bool
) async {
    for _ in 0..<100 where !condition() {
        try? await Task.sleep(for: .milliseconds(1))
    }
}

/// 跨并发边界记录事件顺序的日志。
///
/// 用于断言「先等待服务端退避建议、再重启回合」这一时序要求。
private actor EventLog {
    private(set) var events: [String] = []

    func append(_ event: String) {
        events.append(event)
    }
}
