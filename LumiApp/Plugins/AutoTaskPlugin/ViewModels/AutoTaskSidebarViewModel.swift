import Foundation
import PluginAutoTask
import SwiftUI

private final class AutoTaskNotificationObserverHolder: @unchecked Sendable {
    private var observer: NSObjectProtocol?

    var hasObserver: Bool {
        observer != nil
    }

    deinit {
        remove()
    }

    func set(_ observer: NSObjectProtocol) {
        remove()
        self.observer = observer
    }

    func remove() {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
            self.observer = nil
        }
    }
}

/// AutoTask 右侧栏视图模型
///
/// 负责获取并展示当前会话的任务列表。
/// 通过观察 WindowConversationVM 的变化来切换显示的任务，
/// 并监听任务变更通知自动刷新 UI。
@MainActor
final class AutoTaskSidebarViewModel: ObservableObject, SuperLog {
    nonisolated static let emoji = "📋"
    nonisolated static let verbose: Bool = true

    @Published var tasks: [TaskDisplayItem] = []
    @Published var summary: TaskProgressSummary?
    @Published var isLoading: Bool = false

    private var currentConversationId: String?
    private nonisolated let notificationObserverHolder = AutoTaskNotificationObserverHolder()

    deinit {
        notificationObserverHolder.remove()
    }

    func removeObserver() {
        notificationObserverHolder.remove()
    }

    /// 刷新当前会话的任务列表
    func refresh(conversationId: UUID?) async {
        guard let conversationId else {
            tasks = []
            summary = nil
            currentConversationId = nil
            return
        }

        let cid = conversationId.uuidString
        let conversationChanged = currentConversationId != cid
        currentConversationId = cid

        // 首次绑定通知（仅一次）
        if !notificationObserverHolder.hasObserver {
            Self.logger.info("\(Self.t)Registering autoTaskDidChange observer")
            let observer = NotificationCenter.default.addObserver(
                forName: .autoTaskDidChange,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                let changedCid = notification.userInfo?["conversationId"] as? String
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if let changedCid, changedCid == self.currentConversationId {
                        await self.reloadFromDB()
                    }
                }
            }
            notificationObserverHolder.set(observer)
        }

        // 会话切换或任务变更时都刷新
        if conversationChanged {
            isLoading = true
        }
        await reloadFromDB()
        if conversationChanged {
            isLoading = false
        }
    }

    /// 手动刷新（用于外部事件触发）
    func forceRefresh() async {
        await reloadFromDB()
    }

    // MARK: - Private

    private func reloadFromDB() async {
        guard let cid = currentConversationId else {
            Self.logger.warning("\(Self.t)reloadFromDB: currentConversationId is nil, skip")
            return
        }
        let manager = TaskStateManager.shared
        let fetchedTasks = await manager.fetchTasks(conversationId: cid)
        let fetchedSummary = await manager.getProgressSummary(conversationId: cid)

        if Self.verbose {
            Self.logger.info("\(Self.t)reloadFromDB: cid=\(cid.prefix(8)), tasks=\(fetchedTasks.count), summary=\(fetchedSummary.total) total")
        }

        tasks = fetchedTasks.map { TaskDisplayItem(from: $0) }
        summary = fetchedSummary
    }
}

/// 任务展示用模型
struct TaskDisplayItem: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String?
    let status: TaskItem.TaskStatus
    let order: Int

    var statusSystemImage: String {
        switch status {
        case .pending: "circle"
        case .inProgress: "arrow.triangle.2.circlepath"
        case .completed: "checkmark.circle.fill"
        case .skipped: "forward.circle"
        }
    }

    var statusColor: Color {
        switch status {
        case .pending: .secondary
        case .inProgress: .blue
        case .completed: .green
        case .skipped: .orange
        }
    }

    var statusText: String {
        switch status {
        case .pending: String(localized: "Pending", table: "AutoTask")
        case .inProgress: String(localized: "In Progress", table: "AutoTask")
        case .completed: String(localized: "Completed", table: "AutoTask")
        case .skipped: String(localized: "Skipped", table: "AutoTask")
        }
    }
}

extension TaskDisplayItem {
    init(from task: TaskItem) {
        self.id = task.id
        self.title = task.title
        self.detail = task.detail
        self.status = task.status
        self.order = task.order
    }
}
