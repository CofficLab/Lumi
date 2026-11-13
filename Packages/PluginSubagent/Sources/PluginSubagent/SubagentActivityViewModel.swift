import Combine
import Foundation
import ProviderConversation
import ProviderToolManager

/// 观察当前会话中 `run_subagent` Job 的运行状态，驱动 ChatToolbar 徽标与弹层。
///
/// 数据流与 ToolActivity 的 ViewModel 同构：订阅 ToolManagerProviding 的
/// Job 事件流与会话切换，只保留本插件工具的 Job。事件回调写回 `jobs`
/// 前比对当前选中会话与工具名，旧会话晚到事件、其他工具的事件都不会污染状态。
@MainActor
final class SubagentActivityViewModel: ObservableObject {
    @Published private(set) var jobs: [ToolJob] = []
    /// 运行中任务的「当前时间」。
    ///
    /// 任务进入 `.running` 后可能长时间没有 output/progress 事件，界面没有
    /// 其它重绘来源，耗时就会停在旧值。定时器推进这个值，弹层才能持续刷新。
    @Published private(set) var now: Date

    private let conversations: any ConversationManaging
    private let toolManager: any ToolManagerProviding
    private let dateProvider: () -> Date
    private var tickTask: Task<Void, Never>?
    private var selectedConversationObserver: (any SelectedConversationObserverHandle)?
    private var jobObserver: (any ToolJobObserverHandle)?

    init(
        conversations: any ConversationManaging,
        toolManager: any ToolManagerProviding,
        dateProvider: @escaping () -> Date = Date.init
    ) {
        self.conversations = conversations
        self.toolManager = toolManager
        self.dateProvider = dateProvider
        self.now = dateProvider()

        selectedConversationObserver = conversations.addSelectedConversationObserver { [weak self] _ in
            self?.refresh()
        }
        jobObserver = toolManager.addToolJobObserver { [weak self] event in
            self?.handle(event)
        }
        refresh()
    }

    func cancel() {
        selectedConversationObserver?.cancel()
        selectedConversationObserver = nil
        jobObserver?.cancel()
        jobObserver = nil
        tickTask?.cancel()
        tickTask = nil
    }

    /// 是否有运行中的任务在驱动计时刷新。
    var isTicking: Bool { tickTask != nil }

    var selectedConversationID: UUID? {
        conversations.selectedConversationID
    }

    /// 运行中（未达终态）的子代理委托，按创建时间排序。
    var activeSubagents: [ToolJob] {
        jobs.filter { !$0.status.isTerminal }
    }

    var activeCount: Int { activeSubagents.count }

    /// 已结束的子代理委托，最近结束的在前。
    var finishedSubagents: [ToolJob] {
        jobs
            .filter(\.status.isTerminal)
            .sorted {
                if $0.completedAt != $1.completedAt {
                    return ($0.completedAt ?? $0.updatedAt) > ($1.completedAt ?? $1.updatedAt)
                }
                return $0.id > $1.id
            }
    }

    func refresh() {
        if let conversationID = conversations.selectedConversationID {
            jobs = toolManager.jobs(forConversationID: conversationID).filter {
                $0.toolCall.name == RunSubagentTool.toolName
            }
        } else {
            jobs = []
        }
        syncTicking()
    }

    /// 推进一次「当前时间」。定时器每秒调用；测试注入固定时钟后也可直接调用。
    func tick() {
        now = dateProvider()
    }

    /// 耗时显示用的时间区间。
    ///
    /// 运行中的任务以 `now` 为终点，静默期也能随时间增长；终态任务固定使用
    /// `completedAt`（缺失时退回最后一次事件时间），不再随时间变化。
    func elapsedDuration(for job: ToolJob) -> TimeInterval? {
        guard let startedAt = job.startedAt else { return nil }
        let end = job.completedAt ?? (job.status.isTerminal ? job.updatedAt : now)
        return max(0, end.timeIntervalSince(startedAt))
    }

    func formatDuration(_ value: TimeInterval) -> String {
        if value < 1 { return "<1s" }
        if value < 60 { return String(format: "%.1fs", value) }
        return String(format: "%.1fm", value / 60)
    }

    /// 委托标签：模型在 `description` 参数里给的短标签。
    func label(for job: ToolJob) -> String {
        guard let data = job.toolCall.arguments.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let description = object["description"] as? String,
              !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return pluginLocalization.string("Subagent task")
        }
        return description
    }

    func statusTitle(for job: ToolJob) -> String {
        statusTitle(for: job.status)
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

    /// 任务是否已结束（含执行抛异常与结构化错误结果两种失败形态）。
    func isFailed(_ job: ToolJob) -> Bool {
        switch job.status {
        case .failed, .timedOut:
            return true
        case .completed:
            return job.toolCall.result?.isError == true
        default:
            return false
        }
    }

    /// 只有存在运行中的任务时才启动计时，全部进入终态后立即停止。
    private func syncTicking() {
        if activeSubagents.isEmpty {
            tickTask?.cancel()
            tickTask = nil
        } else if tickTask == nil {
            tickTask = Task { @MainActor [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    guard !Task.isCancelled, let self else { return }
                    self.tick()
                }
            }
        }
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
        case .completed(_, _, let job), .failed(_, _, let job),
             .cancelled(_, _, let job), .timedOut(_, _, let job):
            snapshot = job
        case .restored:
            return
        }

        guard snapshot.conversationID == conversations.selectedConversationID,
              snapshot.toolCall.name == RunSubagentTool.toolName
        else { return }

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
        syncTicking()
    }
}
