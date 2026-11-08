import Combine
import Foundation
import ProviderConversation
import ProviderToolManager

@MainActor
final class ToolActivityViewModel: ObservableObject {
    @Published private(set) var jobs: [ToolJob] = []
    /// 已完成但 `ToolCallResult.isError == true` 的 Job。
    ///
    /// `.completed` 只表示执行过程没有抛异常；工具正常返回结构化失败结果时，
    /// Job 仍是 `.completed`，必须单独保留结果里的 isError 才能显示失败态。
    @Published private(set) var erroredCompletedJobIDs: Set<String> = []

    private let conversations: any ConversationManaging
    private let toolManager: any ToolManagerProviding
    private var selectedConversationObserver: (any SelectedConversationObserverHandle)?
    private var jobObserver: (any ToolJobObserverHandle)?

    init(
        conversations: any ConversationManaging,
        toolManager: any ToolManagerProviding
    ) {
        self.conversations = conversations
        self.toolManager = toolManager

        selectedConversationObserver = conversations.addSelectedConversationObserver { [weak self] id in
            self?.setSelectedConversation(id)
        }
        jobObserver = toolManager.addToolJobObserver { [weak self] event in
            self?.handle(event)
        }
        setSelectedConversation(conversations.selectedConversationID)
    }

    func cancel() {
        selectedConversationObserver?.cancel()
        selectedConversationObserver = nil
        jobObserver?.cancel()
        jobObserver = nil
    }

    var selectedConversationID: UUID? {
        conversations.selectedConversationID
    }

    var activeJobs: [ToolJob] {
        jobs.filter { !$0.status.isTerminal }
    }

    var completedJobs: [ToolJob] {
        jobs
            .filter(\.status.isTerminal)
            .sorted {
                if $0.completedAt != $1.completedAt {
                    return ($0.completedAt ?? $0.updatedAt) > ($1.completedAt ?? $1.updatedAt)
                }
                return $0.id > $1.id
            }
    }

    var activeCount: Int { activeJobs.count }

    func refresh() {
        guard let conversationID = conversations.selectedConversationID else {
            jobs = []
            erroredCompletedJobIDs = []
            return
        }
        jobs = toolManager.jobs(forConversationID: conversationID)
        // 只保留当前会话仍在列表中的 Job，避免切换会话后残留上一会话的错误标记。
        erroredCompletedJobIDs.formIntersection(jobs.map(\.id))
    }

    func displayName(for job: ToolJob) -> String {
        toolManager.displayDescription(for: job.toolCall) ?? job.toolCall.name
    }

    /// 工具是否以结构化错误结果结束（执行过程本身未抛异常）。
    func isErroredResult(for job: ToolJob) -> Bool {
        job.status == .completed && erroredCompletedJobIDs.contains(job.id)
    }

    func statusTitle(for job: ToolJob) -> String {
        isErroredResult(for: job)
            ? pluginLocalization.string("Failed")
            : statusTitle(for: job.status)
    }

    func statusTitle(for status: ToolJobStatus) -> String {
        switch status {
        case .queued:
            return pluginLocalization.string("Queued")
        case .running:
            return pluginLocalization.string("Running")
        case .waitingForUser:
            return pluginLocalization.string("Waiting for you")
        case .cancelling:
            return pluginLocalization.string("Stopping")
        case .completed:
            return pluginLocalization.string("Completed")
        case .failed:
            return pluginLocalization.string("Failed")
        case .cancelled:
            return pluginLocalization.string("Cancelled")
        case .timedOut:
            return pluginLocalization.string("Timed out")
        }
    }

    private func setSelectedConversation(_ id: UUID?) {
        _ = id
        refresh()
    }

    private func handle(_ event: ToolJobEvent) {
        // 启动恢复是批量快照，直接重读当前会话的完整列表。
        if case .restored = event {
            refresh()
            return
        }

        let snapshot: ToolJob
        switch event {
        case .created(let job), .started(let job), .waitingForUser(let job):
            snapshot = job
        case .output(_, _, _, let job), .progress(_, _, let job):
            snapshot = job
        case .completed(_, let result, let job):
            snapshot = job
            if result.isError {
                erroredCompletedJobIDs.insert(job.id)
            } else {
                erroredCompletedJobIDs.remove(job.id)
            }
        case .failed(_, _, let job), .cancelled(_, _, let job), .timedOut(_, _, let job):
            snapshot = job
            erroredCompletedJobIDs.remove(job.id)
        case .restored:
            return
        }

        guard snapshot.conversationID == conversations.selectedConversationID else { return }
        if let index = jobs.firstIndex(where: { $0.id == snapshot.id }) {
            jobs[index] = snapshot
        } else {
            jobs.append(snapshot)
        }
        jobs.sort {
            if $0.createdAt != $1.createdAt {
                return $0.createdAt < $1.createdAt
            }
            return $0.id < $1.id
        }
    }
}
