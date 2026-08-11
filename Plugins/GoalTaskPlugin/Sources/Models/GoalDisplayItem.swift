import SwiftUI

/// Goal 展示用模型(不直接暴露 SwiftData 模型到 View)。
///
/// 将持久化模型 `Goal` 映射为只读的轻量值类型,避免在视图中直接持有
/// SwiftData `@Model`,便于跨 actor 传递与测试。状态相关的展示属性
/// (`statusSystemImage` / `statusColor` / `isTerminal`) 在此集中维护,
/// 视图层仅消费,不再各自 switch。
public struct GoalDisplayItem: Identifiable, Equatable {
    public let id: String
    public let title: String
    public let status: Goal.GoalStatus
    public let blockedReason: String?
    public let goalDescription: String?

    public init(from goal: Goal) {
        self.id = goal.id
        self.title = goal.title
        self.status = goal.status
        self.blockedReason = goal.blockedReason
        self.goalDescription = goal.goalDescription
    }

    /// 是否为终态(completed / failed / skipped),非终态即视为「活跃」。
    public var isTerminal: Bool {
        switch status {
        case .completed, .failed, .skipped: true
        case .pending, .inProgress, .blocked: false
        }
    }

    public var statusSystemImage: String {
        switch status {
        case .pending: "circle"
        case .inProgress: "arrow.triangle.2.circlepath"
        case .completed: "checkmark.circle.fill"
        case .blocked: "exclamationmark.triangle.fill"
        case .failed: "xmark.circle.fill"
        case .skipped: "forward.circle"
        }
    }

    public var statusColor: Color {
        switch status {
        case .pending: .secondary
        case .inProgress: .blue
        case .completed: .green
        case .blocked: .orange
        case .failed: .red
        case .skipped: .gray
        }
    }
}