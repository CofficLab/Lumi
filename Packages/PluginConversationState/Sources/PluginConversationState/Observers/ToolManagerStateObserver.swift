import Foundation
import KitSuperLog
import os
import ProviderConversationState
import ProviderToolManager

/// 将 ToolManager 生命周期和授权事件转换为会话状态更新。
@MainActor
final class ToolManagerStateObserver: SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.conversation-state",
        category: "ToolManagerStateObserver"
    )

    private let provider: ConversationStateProvider
    private var handle: (any ToolManagerObserverHandle)?
    private var jobHandle: (any ToolJobObserverHandle)?
    private var jobsByConversation: [UUID: [String: ToolJob]] = [:]
    private var turnByConversation: [UUID: UUID?] = [:]

    init(toolManager: any ToolManagerProviding, provider: ConversationStateProvider) {
        self.provider = provider
        handle = toolManager.addToolManagerObserver { [weak self] event in
            self?.consume(event)
        }
        jobHandle = toolManager.addToolJobObserver { [weak self] event in
            self?.consume(jobEvent: event)
        }
    }

    func cancel() {
        handle?.cancel()
        handle = nil
        jobHandle?.cancel()
        jobHandle = nil
    }

    private func consume(_ event: ToolManagerEvent) {
        switch event {
        case .started(let id, let turn, _):
            provider.update(conversationID: id, turnID: turn, toolState: .executing, activity: .executingTool)
        case .authorizationRequired(let id, let turn, _):
            provider.update(conversationID: id, turnID: turn, authorizationState: .required, activity: .waitingForUser)
        case .completed(let id, let turn, _, _),
             .batchCompleted(let id, let turn, _, _):
            provider.update(conversationID: id, turnID: turn, toolState: .completed)
        case .authorizedCompleted(let id, let turn, _, _):
            provider.update(
                conversationID: id,
                turnID: turn,
                toolState: .completed,
                authorizationState: ConversationAuthorizationState.none
            )
        }
    }

    private func consume(jobEvent: ToolJobEvent) {
        let job: ToolJob
        switch jobEvent {
        case .created(let snapshot), .started(let snapshot), .waitingForUser(let snapshot):
            job = snapshot
        case .output(_, _, _, let snapshot), .progress(_, _, let snapshot),
             .completed(_, _, let snapshot), .failed(_, _, let snapshot),
             .cancelled(_, _, let snapshot), .timedOut(_, _, let snapshot):
            job = snapshot
        }

        if turnByConversation[job.conversationID] != job.turnID {
            jobsByConversation[job.conversationID] = [:]
            turnByConversation[job.conversationID] = job.turnID
        }
        jobsByConversation[job.conversationID, default: [:]][job.id] = job

        let jobs = jobsByConversation[job.conversationID, default: [:]].values
        let sortedJobs = jobs.sorted { lhs, rhs in
            if lhs.updatedAt == rhs.updatedAt { return lhs.createdAt > rhs.createdAt }
            return lhs.updatedAt > rhs.updatedAt
        }
        let activity = ConversationJobActivity(
            currentJobCount: jobs.count,
            runningJobCount: jobs.filter { !$0.status.isTerminal }.count,
            recentJobDescription: sortedJobs.first?.toolCall.displayDescription ?? sortedJobs.first?.toolCall.name,
            recentJobUpdatedAt: sortedJobs.first?.updatedAt
        )

        let isWaiting = jobs.contains { $0.status == .waitingForUser }
        let hasRunning = jobs.contains { !$0.status.isTerminal }
        provider.update(
            conversationID: job.conversationID,
            turnID: job.turnID,
            toolState: isWaiting ? .suspended : (hasRunning ? .executing : .completed),
            activity: isWaiting ? .waitingForUser : (hasRunning ? .executingTool : nil),
            jobActivity: activity,
            clearActivity: !hasRunning && !isWaiting
        )
    }
}
