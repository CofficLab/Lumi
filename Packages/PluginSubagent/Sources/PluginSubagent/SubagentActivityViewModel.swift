import Combine
import Foundation
import ProviderConversation
import ProviderMessage
import ProviderToolManager

/// 弹层里一行子代理活动（#1328 Task 7）。
///
/// 身份来自父会话里的委托卡片载荷，当前工具与工具数来自子会话的 Job 列表，
/// 待读取消息数来自收件箱协调器。载荷尚未落库时 `name`/`childConversationID`
/// 为 nil，行仍可退化为任务标签展示。
struct SubagentActivityItem: Identifiable, Equatable {
    let job: ToolJob
    let name: String?
    let childConversationID: UUID?
    let currentToolName: String?
    let completedToolCount: Int
    let pendingMessageCount: Int

    var id: String { job.id }
}

/// 胶囊状态：失败 > 等待用户 > 运行中 > 空闲。
enum SubagentActivityStatus: Equatable {
    case idle
    case running
    case waiting
    case failure
}

/// 观察当前会话中 `run_subagent` Job 的运行状态，驱动 ChatToolbar 徽标与弹层。
///
/// 数据流与 ToolActivity 的 ViewModel 同构：订阅 ToolManagerProviding 的
/// Job 事件流与会话切换，只保留本插件工具的 Job。事件回调写回 `jobs`
/// 前比对当前选中会话与工具名，旧会话晚到事件、其他工具的事件都不会污染状态。
///
/// Phase 2 起额外派生 `items`：父 Job 对应子会话里的实时活动（当前工具、
/// 已完成工具数、待读取消息数）。子会话的 Job 事件只刷新活动数据，不会
/// 进入 `jobs` 徽标列表。
@MainActor
final class SubagentActivityViewModel: ObservableObject {
    @Published private(set) var jobs: [ToolJob] = []
    /// 当前会话每个委托的活动快照，顺序与 `jobs` 一致。
    @Published private(set) var items: [SubagentActivityItem] = []
    /// 运行中任务的「当前时间」。
    ///
    /// 任务进入 `.running` 后可能长时间没有 output/progress 事件，界面没有
    /// 其它重绘来源，耗时就会停在旧值。定时器推进这个值，弹层才能持续刷新。
    @Published private(set) var now: Date

    private let conversations: any ConversationManaging
    private let toolManager: any ToolManagerProviding
    private let messages: (any MessageManaging)?
    private let dateProvider: () -> Date
    /// 子会话里尚未读取的代理消息数（由 `SubagentInboxCoordinator` 提供）。
    private let pendingMessageCountProvider: (UUID) -> Int
    private var tickTask: Task<Void, Never>?
    private var selectedConversationObserver: (any SelectedConversationObserverHandle)?
    private var jobObserver: (any ToolJobObserverHandle)?
    private var messageObserver: (any MessageChangeObserverHandle)?
    /// 父会话委托卡片载荷，按 `run_subagent` Job ID 索引。
    private var timelineByJobID: [String: SubagentTimeline.Payload] = [:]
    /// 丢弃过期异步读取：会话切换或连续刷新时只采纳最后一次结果。
    private var timelineGeneration = 0

    init(
        conversations: any ConversationManaging,
        toolManager: any ToolManagerProviding,
        messages: (any MessageManaging)? = nil,
        dateProvider: @escaping () -> Date = Date.init,
        pendingMessageCountProvider: @escaping (UUID) -> Int = { _ in 0 }
    ) {
        self.conversations = conversations
        self.toolManager = toolManager
        self.messages = messages
        self.dateProvider = dateProvider
        self.pendingMessageCountProvider = pendingMessageCountProvider
        self.now = dateProvider()

        selectedConversationObserver = conversations.addSelectedConversationObserver { [weak self] _ in
            self?.refresh()
        }
        jobObserver = toolManager.addToolJobObserver { [weak self] event in
            self?.handle(event)
        }
        messageObserver = messages?.addMessageChangeObserver { [weak self] change in
            self?.handle(change)
        }
        refresh()
    }

    func cancel() {
        selectedConversationObserver?.cancel()
        selectedConversationObserver = nil
        jobObserver?.cancel()
        jobObserver = nil
        messageObserver?.cancel()
        messageObserver = nil
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

    /// 胶囊状态：任何失败 = red，有人等用户 = orange，运行中 = accent。
    var status: SubagentActivityStatus {
        if items.contains(where: { isFailed($0.job) }) {
            return .failure
        }
        if items.contains(where: { $0.job.status == .waitingForUser }) {
            return .waiting
        }
        if items.contains(where: { !$0.job.status.isTerminal }) {
            return .running
        }
        return .idle
    }

    /// 胶囊上的数字：需要处理 + 运行中。
    ///
    /// 失败项已进入终态、不计入 `activeCount`，但仍需让用户看到红色徽标，
    /// 所以胶囊计数包含注意力项；正常结束的委托不再占数字。
    var capsuleCount: Int {
        attentionItems.count + runningItems.count
    }

    /// 需用户处理的活动：等待批准/回答，或已失败。
    ///
    /// 等待中的排在最前——它是唯一会卡住委托、必须由人解开的；失败随后，
    /// 按结束时间倒序。
    var attentionItems: [SubagentActivityItem] {
        items
            .filter { needsAttention($0) }
            .sorted {
                let lhsWaiting = $0.job.status == .waitingForUser
                let rhsWaiting = $1.job.status == .waitingForUser
                if lhsWaiting != rhsWaiting {
                    return lhsWaiting
                }
                let lhsDate = $0.job.completedAt ?? $0.job.updatedAt
                let rhsDate = $1.job.completedAt ?? $1.job.updatedAt
                if lhsDate != rhsDate {
                    return lhsDate > rhsDate
                }
                return $0.id > $1.id
            }
    }

    /// 其余未终态委托，按创建时间排序。
    var runningItems: [SubagentActivityItem] {
        items
            .filter { !needsAttention($0) && !$0.job.status.isTerminal }
            .sorted {
                if $0.job.createdAt != $1.job.createdAt {
                    return $0.job.createdAt < $1.job.createdAt
                }
                return $0.id < $1.id
            }
    }

    /// 正常结束的委托，最近结束的在前。
    var finishedItems: [SubagentActivityItem] {
        items
            .filter { !needsAttention($0) && $0.job.status.isTerminal }
            .sorted {
                let lhsDate = $0.job.completedAt ?? $0.job.updatedAt
                let rhsDate = $1.job.completedAt ?? $1.job.updatedAt
                if lhsDate != rhsDate {
                    return lhsDate > rhsDate
                }
                return $0.id > $1.id
            }
    }

    func needsAttention(_ item: SubagentActivityItem) -> Bool {
        needsAttention(item.job)
    }

    func needsAttention(_ job: ToolJob) -> Bool {
        job.status == .waitingForUser || isFailed(job)
    }

    /// 行标题：树内稳定名字；旧委托没有名字时退回任务标签。
    func name(for item: SubagentActivityItem) -> String {
        if let name = item.name, !name.isEmpty {
            return name
        }
        return "(unnamed)"
    }

    func refresh() {
        if let conversationID = conversations.selectedConversationID {
            jobs = toolManager.jobs(forConversationID: conversationID).filter {
                $0.toolCall.name == RunSubagentTool.toolName
            }
        } else {
            jobs = []
        }
        reloadTimeline()
        rebuildItems()
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

    // MARK: - Activity items

    /// 异步读取父会话的委托卡片，建立 Job ID → 载荷的索引。
    ///
    /// 卡片是身份的持久化来源：名字与子会话 ID 都只从这里取。异步读取
    /// 带会话与代际校验，避免旧会话的晚到结果覆盖新会话。
    private func reloadTimeline() {
        timelineGeneration += 1
        guard let messages, let conversationID = conversations.selectedConversationID else {
            timelineByJobID = [:]
            return
        }
        let generation = timelineGeneration
        Task { @MainActor [weak self] in
            let snapshot = await messages.messagesSnapshot(in: conversationID)
            guard let self,
                  generation == self.timelineGeneration,
                  self.conversations.selectedConversationID == conversationID
            else { return }
            var payloads: [String: SubagentTimeline.Payload] = [:]
            for message in snapshot {
                guard let payload = SubagentTimeline.decodePayload(from: message.metadata),
                      payload.parentConversationID == conversationID
                else { continue }
                payloads[payload.jobID] = payload
            }
            self.timelineByJobID = payloads
            self.rebuildItems()
        }
    }

    private func rebuildItems() {
        items = jobs.map { job in
            let payload = timelineByJobID[job.id]
            let childID = payload?.childConversationID
            let (currentTool, completedCount) = childID.map(childActivity(for:)) ?? (nil, 0)
            return SubagentActivityItem(
                job: job,
                name: payload?.name ?? nameArgument(for: job),
                childConversationID: childID,
                currentToolName: currentTool,
                completedToolCount: completedCount,
                pendingMessageCount: childID.map(pendingMessageCountProvider) ?? 0
            )
        }
    }

    /// 子会话里正在执行的工具与已完成的工具数。
    private func childActivity(for conversationID: UUID) -> (String?, Int) {
        let childJobs = toolManager.jobs(forConversationID: conversationID)
        let active = childJobs
            .filter { !$0.status.isTerminal }
            .max { $0.updatedAt < $1.updatedAt }
        let completed = childJobs.filter(\.status.isTerminal).count
        return (active?.toolCall.name, completed)
    }

    /// 载荷尚未落库时的退化身份：`run_subagent` 参数里的 `name`。
    private func nameArgument(for job: ToolJob) -> String? {
        guard let data = job.toolCall.arguments.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let name = object["name"] as? String,
              !name.isEmpty
        else { return nil }
        return name
    }

    private func handle(_ change: MessageChange) {
        guard let conversationID = conversations.selectedConversationID else { return }
        switch change {
        case .inserted(let message, let insertedConversationID):
            guard insertedConversationID == conversationID,
                  MessageTimelineEvent.isSubagentDelegation(message)
            else { return }
            reloadTimeline()
        case .deleted(_, let deletedConversationID), .cleared(let deletedConversationID):
            guard deletedConversationID == conversationID else { return }
            reloadTimeline()
        case .persisted, .updated:
            break
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

        // 子会话里的工具事件不进入父会话徽标，只刷新活动行。
        if snapshot.conversationID != conversations.selectedConversationID {
            if timelineByJobID.values.contains(where: {
                $0.childConversationID == snapshot.conversationID
            }) {
                rebuildItems()
            }
            return
        }

        guard snapshot.toolCall.name == RunSubagentTool.toolName else { return }

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
        rebuildItems()
        syncTicking()
    }
}
