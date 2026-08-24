import SwiftUI

/// GoalTask 展示用模型(不直接暴露 SwiftData 模型到 View)。
///
/// 将持久化模型 `GoalTask` 映射为只读的轻量值类型,供视图层与 ViewModel
/// 安全使用。展示相关的派生属性(`statusSystemImage` / `statusColor`)
/// 集中在此,避免视图层各自重复 switch。
public struct GoalTaskDisplayItem: Identifiable, Equatable {
    public let id: String
    public let title: String
    public let status: GoalTask.TaskStatus
    public let parallelGroup: String?

    public init(from task: GoalTask) {
        self.id = task.id
        self.title = task.title
        self.status = task.status
        self.parallelGroup = task.parallelGroup
    }

    public var statusSystemImage: String {
        switch status {
        case .pending: "circle"
        case .inProgress: "arrow.triangle.2.circlepath"
        case .completed: "checkmark.circle.fill"
        case .failed: "xmark.circle.fill"
        case .skipped: "forward.circle"
        }
    }

    public var statusColor: Color {
        switch status {
        case .pending: .secondary
        case .inProgress: .blue
        case .completed: .green
        case .failed: .red
        case .skipped: .orange
        }
    }
}