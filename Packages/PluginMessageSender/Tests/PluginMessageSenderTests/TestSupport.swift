import Foundation
import ProviderAgentLoop
import ProviderLifecycleHooks
import ProviderMessage
import Testing

// MARK: - AgentLoop Stub

/// 测试用 AgentLoop 桩：最小实现，可配置回合结果并记录取消调用。
///
/// 刻意不自动响应消息插入——回合的推进完全由测试显式投递 `AgentLoopEvent`，
/// 这样「提交 → 入队 → 停止 → 排空」的每一步时序都可断言。
@MainActor
final class StubAgentLoop: AgentLoopProviding {
    private let messages: any MessageManaging
    private var observers: [UUID: (AgentLoopEvent) -> Void] = [:]

    /// `runTurn` 写入的助手消息内容。
    var responseContent: String = "response"
    /// `resumeTurn` 的成功结果；默认 `.completed`。
    var resumeOutcome: AgentLoopOutcome = .completed
    /// 非 nil 时 `resumeTurn` 抛出该错误，覆盖失败分支。
    var resumeError: (any Error)?
    /// 被 `cancelTurn` 取消过的会话，按调用顺序记录。
    private(set) var cancelledConversationIDs: [UUID] = []
    /// `runTurn` 被调用的次数。
    private(set) var runTurnCount = 0

    // 供 `handleAgentLoopEvent` 的迟到事件校验读取
    var currentState: AgentLoopState = .idle
    var activeTurnID: UUID?
    var activeSuspension: AgentLoopSuspension?

    init(messages: any MessageManaging) {
        self.messages = messages
    }

    /// 当前仍注册的观察者数量，用于验证插件 shutdown 后监听确实被拆除。
    var observerCount: Int { observers.count }

    func addAgentLoopObserver(
        _ callback: @escaping (AgentLoopEvent) -> Void
    ) -> any AgentLoopObserverHandle {
        let id = UUID()
        observers[id] = callback
        return StubAgentLoopObserverHandle { [weak self] in
            self?.observers.removeValue(forKey: id)
        }
    }

    func notify(_ event: AgentLoopEvent) {
        for callback in observers.values { callback(event) }
    }

    func runTurn(in conversationID: UUID) async throws -> AgentLoopOutcome {
        runTurnCount += 1
        messages.insertMessage(
            Message(conversationID: conversationID, role: .assistant, content: responseContent),
            to: conversationID
        )
        return .completed
    }

    func resumeTurn(in conversationID: UUID, request: AgentTurnResumeRequest) async throws -> AgentLoopOutcome {
        if let resumeError { throw resumeError }
        return resumeOutcome
    }

    func cancelTurn(in conversationID: UUID) {
        cancelledConversationIDs.append(conversationID)
    }

    func state(for conversationID: UUID) -> AgentLoopState { currentState }
    func suspension(for conversationID: UUID) -> AgentLoopSuspension? { activeSuspension }
    /// 与真实 AgentLoop 一致：状态为 `.running` 才算在跑。
    ///
    /// 停止判定权在 AgentLoop 手上（见 `MessageSender.cancelCurrentRequest`），
    /// 桩若恒返回 false 就测不出「sender 不知道的回合也必须能停」。
    func isRunning(for conversationID: UUID) -> Bool { currentState == .running }
    func currentTurnID(for conversationID: UUID) -> UUID? { activeTurnID }
    func setLifecycleHooks(_ hooks: (any LifecycleHooksProviding)?) {}
}

@MainActor
final class StubAgentLoopObserverHandle: AgentLoopObserverHandle {
    private var cancellation: (() -> Void)?

    init(cancellation: @escaping () -> Void) {
        self.cancellation = cancellation
    }

    func cancel() {
        cancellation?()
        cancellation = nil
    }
}

// MARK: - Test Errors

/// `resumeTurn` 失败分支使用的固定错误。
///
/// 遵循 `LocalizedError` 使 `localizedDescription` 返回可断言的文案——被测代码在
/// `turnFailed` 事件与错误消息落库时都使用该文案。
struct StubAgentLoopError: LocalizedError, Equatable {
    let reason: String

    var errorDescription: String? { reason }
}

// MARK: - Helpers

/// 轮询等待条件成立；用于等待被测代码在 MainActor 上推进到下一个稳定点。
///
/// 被测回合跟踪任务与测试同在主 actor，协作式调度下 `Task.yield()` 足以让出执行权。
@MainActor
func waitUntil(
    timeout: Duration = .seconds(5),
    _ condition: @MainActor () -> Bool
) async {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: timeout)
    while !condition() {
        if clock.now >= deadline {
            Issue.record("等待条件超时")
            return
        }
        await Task.yield()
    }
}

// MARK: - Fixtures

extension UserImageAttachment {
    static func fixture(
        id: UUID = UUID(),
        mimeType: String = "image/png",
        base64Data: String = "aW1hZ2U="
    ) -> UserImageAttachment {
        UserImageAttachment(id: id, mimeType: mimeType, base64Data: base64Data)
    }
}

extension UserFileAttachment {
    static func fixture(
        id: UUID = UUID(),
        fileName: String = "notes.txt",
        mimeType: String = "text/plain",
        textContent: String? = "hello"
    ) -> UserFileAttachment {
        UserFileAttachment(
            id: id,
            fileName: fileName,
            mimeType: mimeType,
            textContent: textContent
        )
    }
}
