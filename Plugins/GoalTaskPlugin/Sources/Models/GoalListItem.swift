import Foundation

/// 一个 Goal 及其任务的展示组合。
///
/// 作为 `GoalVM.goals` 列表的元素类型,同时被工具栏弹窗
/// (`GoalPopoverContent`)与侧栏(经 `GoalVM` 派生)消费,
/// 因此保持 `internal` 可见性;若日后被其他模块引用,可提升为 `public`。
struct GoalListItem: Identifiable, Equatable {
    let goal: GoalDisplayItem
    let tasks: [GoalTaskDisplayItem]

    var id: String { goal.id }
}