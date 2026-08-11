import Foundation

/// 一个 Goal 及其任务的展示组合(用于工具栏弹窗的列表项)。
///
/// 当前仅在 `GoalToolbarViewModel` 与对应的弹窗视图之间传递,
/// 因此保持 `internal` 可见性;若日后被其他模块引用,可提升为 `public`。
struct GoalListItem: Identifiable, Equatable {
    let goal: GoalDisplayItem
    let tasks: [GoalTaskDisplayItem]

    var id: String { goal.id }
}