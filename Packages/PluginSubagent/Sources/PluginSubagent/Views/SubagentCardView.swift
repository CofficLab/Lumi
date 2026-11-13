import LumiUI
import ProviderMessage
import ProviderToolManager
import SwiftUI

/// 子代理委托卡片视图（#1313 Task 6）。
///
/// 展示委托标签、状态、子代理工具调用数与耗时。数据全部来自工具管理器：
/// 父 Job 给状态与耗时，子会话的 Job 列表给工具数——载荷本身只存标识，
/// 持久化的 Job 快照保证用户过几天回看时终态依然可读。
///
/// 运行中订阅 Job 事件并每秒推进「当前时间」，静默期耗时也能增长；
/// 全部终态后停止计时（与 ToolActivity / 子代理徽标同款约定）。
struct SubagentCardView: View {
    @LumiTheme private var theme

    let payload: SubagentTimeline.Payload
    /// 工具管理器：缺席时只显示载荷里的静态信息。
    let toolManager: (any ToolManagerProviding)?

    @State private var job: ToolJob?
    @State private var childToolCount = 0
    @State private var now = Date()
    @State private var tickTask: Task<Void, Never>?
    @State private var jobObserver: (any ToolJobObserverHandle)?

    var body: some View {
        AppCard(style: .subtle, cornerRadius: 12) {
            VStack(alignment: .leading, spacing: 12) {
                header

                Divider()
                    .overlay(theme.divider.opacity(0.6))

                detailRows
            }
        }
        .onAppear { startObserving() }
        .onDisappear { stopObserving() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: statusIcon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(statusColor)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(String(localized: "Subagent", bundle: .module))
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(theme.textPrimary)

                Text(payload.label)
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Text(statusTitle)
                .font(.caption)
                .foregroundStyle(theme.textSecondary)
        }
    }

    // MARK: - Details

    private var detailRows: some View {
        VStack(alignment: .leading, spacing: 6) {
            detailRow(
                icon: "wrench.and.screwdriver",
                title: String(localized: "Tool calls", bundle: .module),
                value: String(childToolCount)
            )
            detailRow(
                icon: "clock",
                title: String(localized: "Duration", bundle: .module),
                value: durationText
            )
        }
    }

    private func detailRow(icon: String, title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(theme.textSecondary)
                .frame(width: 16)

            Text(title)
                .font(.caption)
                .foregroundStyle(theme.textSecondary)

            Spacer(minLength: 8)

            Text(value)
                .font(.caption.monospacedDigit())
                .foregroundStyle(theme.textPrimary)
        }
    }

    // MARK: - Derived state

    private var status: ToolJobStatus { job?.status ?? .queued }

    private var statusTitle: String {
        switch status {
        case .queued: return String(localized: "Queued", bundle: .module)
        case .running: return String(localized: "Running", bundle: .module)
        case .waitingForUser: return String(localized: "Waiting for you", bundle: .module)
        case .cancelling: return String(localized: "Stopping", bundle: .module)
        case .completed: return String(localized: "Completed", bundle: .module)
        case .failed: return String(localized: "Failed", bundle: .module)
        case .cancelled: return String(localized: "Cancelled", bundle: .module)
        case .timedOut: return String(localized: "Timed out", bundle: .module)
        }
    }

    private var statusIcon: String {
        switch status {
        case .queued: return "clock"
        case .running, .cancelling: return "arrow.triangle.2.circlepath"
        case .waitingForUser: return "hand.raised"
        case .completed: return "checkmark.circle.fill"
        case .failed, .timedOut: return "exclamationmark.triangle.fill"
        case .cancelled: return "xmark.circle"
        }
    }

    private var statusColor: Color {
        switch status {
        case .completed: return theme.success
        case .failed, .timedOut: return theme.error
        case .cancelled: return theme.textSecondary
        default: return theme.primary
        }
    }

    /// 耗时：运行中以「当前时间」为终点，终态固定在完成时刻。
    private var durationText: String {
        guard let startedAt = job?.startedAt else { return "—" }
        let end = job?.completedAt ?? (status.isTerminal ? (job?.updatedAt ?? now) : now)
        let value = max(0, end.timeIntervalSince(startedAt))
        if value < 1 { return "<1s" }
        if value < 60 { return String(format: "%.1fs", value) }
        return String(format: "%.1fm", value / 60)
    }

    // MARK: - Observation

    private func startObserving() {
        guard let toolManager else { return }
        refresh(from: toolManager)

        jobObserver = toolManager.addToolJobObserver { event in
            Task { @MainActor in
                handle(event)
            }
        }
        syncTicking()
    }

    private func stopObserving() {
        jobObserver?.cancel()
        jobObserver = nil
        tickTask?.cancel()
        tickTask = nil
    }

    private func refresh(from toolManager: any ToolManagerProviding) {
        job = toolManager.jobs(forConversationID: payload.parentConversationID)
            .first(where: { $0.id == payload.jobID })
        childToolCount = toolManager.jobs(forConversationID: payload.childConversationID)
            .filter { $0.status.isTerminal }.count
    }

    private func handle(_ event: ToolJobEvent) {
        let snapshot: ToolJob
        switch event {
        case .created(let job), .started(let job), .waitingForUser(let job):
            snapshot = job
        case .output(_, _, _, let job), .progress(_, _, let job):
            snapshot = job
        case .completed(_, _, let job), .failed(_, _, let job),
             .cancelled(_, _, let job), .timedOut(_, _, let job):
            snapshot = job
        case .restored(let jobs):
            if let restored = jobs.first(where: { $0.id == payload.jobID }) {
                job = restored
            }
            if let toolManager {
                childToolCount = toolManager.jobs(forConversationID: payload.childConversationID)
                    .filter { $0.status.isTerminal }.count
            }
            syncTicking()
            return
        }

        if snapshot.id == payload.jobID {
            job = snapshot
            syncTicking()
        } else if snapshot.conversationID == payload.childConversationID,
                  snapshot.status.isTerminal {
            childToolCount += 1
        }
    }

    /// 只有父 Job 未达终态时才计时；终态后立即停止。
    private func syncTicking() {
        if status.isTerminal {
            tickTask?.cancel()
            tickTask = nil
        } else if tickTask == nil {
            tickTask = Task { @MainActor in
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    guard !Task.isCancelled else { return }
                    now = Date()
                }
            }
        }
    }
}

/// 载荷缺失时的回退视图。
struct SubagentCardFallbackView: View {
    let message: Message

    var body: some View {
        Text(message.content)
            .font(.callout)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
    }
}