import Foundation
import MagicKit
import SwiftUI

/// AutoTask 右侧栏视图模型
///
/// 负责获取并展示当前会话的任务列表。
/// 通过观察 ConversationVM 的变化来切换显示的任务。
@MainActor
final class AutoTaskSidebarViewModel: ObservableObject {
    @Published var tasks: [TaskDisplayItem] = []
    @Published var summary: TaskProgressSummary?
    @Published var isLoading: Bool = false

    private var currentConversationId: String?

    /// 刷新当前会话的任务列表
    func refresh(conversationId: UUID?) async {
        guard let conversationId else {
            tasks = []
            summary = nil
            return
        }

        let cid = conversationId.uuidString
        guard currentConversationId != cid else { return }
        currentConversationId = cid

        isLoading = true
        let manager = TaskStateManager.shared
        let fetchedTasks = await manager.fetchTasks(conversationId: cid)
        let fetchedSummary = await manager.getProgressSummary(conversationId: cid)

        tasks = fetchedTasks.map { TaskDisplayItem(from: $0) }
        summary = fetchedSummary
        isLoading = false
    }

    /// 手动刷新（用于外部事件触发）
    func forceRefresh() async {
        guard let cid = currentConversationId else { return }
        isLoading = true
        let manager = TaskStateManager.shared
        let fetchedTasks = await manager.fetchTasks(conversationId: cid)
        let fetchedSummary = await manager.getProgressSummary(conversationId: cid)

        tasks = fetchedTasks.map { TaskDisplayItem(from: $0) }
        summary = fetchedSummary
        isLoading = false
    }
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
