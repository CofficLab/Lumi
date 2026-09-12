import Foundation
import Testing
import ProviderAgentLoop
@testable import ProviderConversationState

@Test("工具任务活动摘要可编码往返并按 current count 判断是否有任务")
func jobActivityCodableAndPresence() throws {
    let activity = ConversationJobActivity(
        currentJobCount: 2,
        runningJobCount: 1,
        recentJobDescription: "正在读取文件",
        recentJobUpdatedAt: Date(timeIntervalSince1970: 123)
    )
    let encoded = try JSONEncoder().encode(activity)
    let decoded = try JSONDecoder().decode(ConversationJobActivity.self, from: encoded)

    #expect(decoded == activity)
    #expect(activity.hasJobs)
    #expect(!ConversationJobActivity().hasJobs)
}

@Test("会话状态 isSending 只在 AgentLoop running 时为 true")
func snapshotSendingStateReflectsAgentLoop() {
    let conversationID = UUID()
    let running = ConversationStateSnapshot(
        conversationID: conversationID,
        turnID: UUID(),
        agentLoopState: .running,
        activity: .thinking
    )
    let suspended = ConversationStateSnapshot(
        conversationID: conversationID,
        agentLoopState: .suspended,
        activity: .waitingForUser
    )
    let idle = ConversationStateSnapshot(conversationID: conversationID)

    #expect(running.isSending)
    #expect(!suspended.isSending)
    #expect(!idle.isSending)
    #expect(idle.toolState == .idle)
    #expect(idle.authorizationState == .none)
    #expect(idle.jobActivity == ConversationJobActivity())
}

@Test("会话状态快照保留完整活动、授权、工具及错误信息")
func snapshotStoresConversationState() throws {
    let conversationID = UUID()
    let turnID = UUID()
    let jobActivity = ConversationJobActivity(
        currentJobCount: 3,
        runningJobCount: 2,
        recentJobDescription: "写入文件",
        recentJobUpdatedAt: Date(timeIntervalSince1970: 456)
    )
    let snapshot = ConversationStateSnapshot(
        conversationID: conversationID,
        turnID: turnID,
        agentLoopState: .suspended,
        toolState: .suspended,
        authorizationState: .required,
        activity: .waitingForUser,
        jobActivity: jobActivity,
        lastError: "permission required"
    )
    let copy = ConversationStateSnapshot(
        conversationID: conversationID,
        turnID: turnID,
        agentLoopState: .suspended,
        toolState: .suspended,
        authorizationState: .required,
        activity: .waitingForUser,
        jobActivity: jobActivity,
        lastError: "permission required"
    )

    #expect(snapshot == copy)
    #expect(snapshot.turnID == turnID)
    #expect(snapshot.lastError == "permission required")
    #expect(snapshot.jobActivity.runningJobCount == 2)
}

@MainActor
@Test("状态变更事件携带会话 ID，默认 observer handle 可以安全取消")
func conversationStateEventsAndDefaultObserver() {
    let conversationID = UUID()
    #expect(ConversationStateEvent.updated(conversationID) == .updated(conversationID))
    #expect(ConversationStateEvent.removed(conversationID) == .removed(conversationID))

    let provider = StubConversationStateProvider(conversationID: conversationID)
    let handle = provider.addConversationStateObserver { _ in
        Issue.record("default observer must not publish events")
    }

    #expect(handle is NoopConversationStateObserverHandle)
    handle.cancel()
    #expect(provider.state(for: conversationID).conversationID == conversationID)
}

@MainActor
private final class StubConversationStateProvider: ConversationStateProviding {
    private let snapshot: ConversationStateSnapshot

    init(conversationID: UUID) {
        snapshot = ConversationStateSnapshot(conversationID: conversationID)
    }

    var states: [UUID: ConversationStateSnapshot] { [snapshot.conversationID: snapshot] }

    func state(for conversationID: UUID) -> ConversationStateSnapshot {
        states[conversationID] ?? ConversationStateSnapshot(conversationID: conversationID)
    }
}
