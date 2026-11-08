import Foundation
import LumiLoggingKit
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
    /// 仍在等待用户授权的回合。审批调用不产生 ToolJob，Job 事件不能决定
    /// 是否清除「等待你的输入」，否则后台 Job 的进度会覆盖授权提示（#962）。
    private var authorizationTurnByConversation: [UUID: UUID?] = [:]

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
        case .toolsChanged:
            break
        case .started(let id, let turn, _):
            // 新回合一旦开始，上一回合遗留的授权等待不再有效。
            if let pendingTurn = authorizationTurnByConversation[id], pendingTurn != turn {
                authorizationTurnByConversation.removeValue(forKey: id)
            }
            provider.update(conversationID: id, turnID: turn, toolState: .executing, activity: .executingTool)
        case .authorizationRequired(let id, let turn, _):
            authorizationTurnByConversation[id] = turn
            provider.update(conversationID: id, turnID: turn, authorizationState: .required, activity: .waitingForUser)
        case .completed(let id, let turn, _, _):
            provider.update(conversationID: id, turnID: turn, toolState: .completed)
        case .batchCompleted(let id, let turn, _, let results):
            // 批次结束意味着这批调用已全部有结果：要么执行完，要么被策略拦截。
            //
            // - Important: Chat 模式的 `.blockAll` 只生成 blocked 结果，不执行
            //   工具、也不创建 ToolJob，因此 Job 终态路径的 activity 清理永远不会
            //   触发。若这里不清理，`.executingTool` 会一路带到下一次 LLM 请求，
            //   界面上持续显示「正在执行」，而实际没有任何工具在跑（#992）。
            //
            //   仍有需要用户授权的调用时保留 `waitingForUser`，交给后续的
            //   `authorizedCompleted` 收尾。
            let hasPendingApproval = results.contains { result in
                if case .needsUserResponse = result { return true }
                return false
            }
            if !hasPendingApproval {
                authorizationTurnByConversation.removeValue(forKey: id)
            }
            provider.update(
                conversationID: id,
                turnID: turn,
                toolState: .completed,
                clearActivity: !hasPendingApproval
            )
        case .authorizedCompleted(let id, let turn, _, _):
            authorizationTurnByConversation.removeValue(forKey: id)
            // 授权已解决（无论允许还是拒绝），「等待用户」这个状态到此结束。
            //
            // - Important: 这里**必须**清掉 activity。授权路径**不产生**
            //   ToolJobEvent（需要授权的调用走 `executeBatch` 兼容路径，
            //   既不调 `submit(...)` 也不发 job 事件），因此
            //   `authorizedCompleted` 是授权链路**唯一**的收尾事件——
            //   若不在这里清理，activity 会永远停在 `.waitingForUser`，
            //   界面上就一直挂着「等待你的输入…」，而此时已无任何卡片可回答。
            //
            //   参见 `AuthorizationActivityResidueTests` 的取证。
            provider.update(
                conversationID: id,
                turnID: turn,
                toolState: .completed,
                authorizationState: ConversationAuthorizationState.none,
                clearActivity: true
            )
        }
    }

    private func consume(jobEvent: ToolJobEvent) {
        // 启动恢复是一批终态历史任务，逐条并入状态机。
        if case .restored(let jobs) = jobEvent {
            for job in jobs {
                ingest(job)
            }
            return
        }

        let job: ToolJob
        switch jobEvent {
        case .created(let snapshot), .started(let snapshot), .waitingForUser(let snapshot):
            job = snapshot
        case .output(_, _, _, let snapshot), .progress(_, _, let snapshot),
             .completed(_, _, let snapshot), .failed(_, _, let snapshot),
             .cancelled(_, _, let snapshot), .timedOut(_, _, let snapshot):
            job = snapshot
        case .restored:
            return
        }

        ingest(job)
    }

    private func ingest(_ job: ToolJob) {
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
        let activeJob = sortedJobs.first(where: { !$0.status.isTerminal })
        let activity = ConversationJobActivity(
            currentJobCount: jobs.count,
            runningJobCount: jobs.filter { !$0.status.isTerminal }.count,
            recentJobDescription: (activeJob ?? sortedJobs.first)?.toolCall.displayDescription
                ?? (activeJob ?? sortedJobs.first)?.toolCall.name,
            recentJobUpdatedAt: (activeJob ?? sortedJobs.first)?.updatedAt
        )

        let isWaiting = jobs.contains { $0.status == .waitingForUser }
        let hasRunning = jobs.contains { !$0.status.isTerminal }
        // 授权仍未解决时，主活动必须保持 waitingForUser；后台 Job 只能更新
        // jobActivity，不能把提示改成「正在执行」或在完成时将其清除（#962）。
        let awaitsAuthorization = {
            guard let pendingTurn = authorizationTurnByConversation[job.conversationID] else { return false }
            return pendingTurn == job.turnID
        }()
        provider.update(
            conversationID: job.conversationID,
            turnID: job.turnID,
            toolState: isWaiting ? .suspended : (hasRunning ? .executing : .completed),
            activity: awaitsAuthorization
                ? .waitingForUser
                : (isWaiting ? .waitingForUser : (hasRunning ? .executingTool : nil)),
            jobActivity: activity,
            clearActivity: !awaitsAuthorization && !hasRunning && !isWaiting
        )
    }
}
