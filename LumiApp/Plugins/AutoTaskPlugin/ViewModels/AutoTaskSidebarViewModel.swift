import Foundation
import MagicKit
import SwiftUI

/// AutoTask 右侧栏视图模型
///
/// 负责获取并展示当前会话的任务列表。
/// 通过观察 ConversationVM 的变化来切换显示的任务，
/// 并监听任务变更通知自动刷新 UI。
@MainActor
final class AutoTaskSidebarViewModel: ObservableObject {
    @Published var tasks: [TaskDisplayItem] = []
    @Published var summary: TaskProgressSummary?
    @Published var isLoading: Bool = false

    private var currentConversationId: String?
    private var notificationObserver: NSObjectProtocol?

    // nonisolated deinit 无法访问 @MainActor 属性，
    // 在 view 消失时通过 onDisappear 移除观察者
    func removeObserver() {
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
            notificationObserver = nil
        }
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
        if notificationObserver == nil {
            notificationObserver = NotificationCenter.default.addObserver(
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
        guard let cid = currentConversationId else { return }
        let manager = TaskStateManager.shared
        let fetchedTasks = await manager.fetchTasks(conversationId: cid)
        let fetchedSummary = await manager.getProgressSummary(conversationId: cid)

        tasks = fetchedTasks.map { TaskDisplayItem(from: $0) }
        summary = fetchedSummary
    }
}

// MARK: - Notification Name

extension Notification.Name {
    /// 任务数据变更通知
    static let autoTaskDidChange = Notification.Name("autoTaskDidChange")
}

/// 任务展示用模型
struct TaskDisplayItem: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String?
    let status: TaskItem.TaskStatus
    let order: Int

    var statusIcon: String {
        switch status {
        case .pending: "⬜"
        case .inProgress: "🔄"
        case .completed: "✅"
        case .skipped: "⏭️"
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
