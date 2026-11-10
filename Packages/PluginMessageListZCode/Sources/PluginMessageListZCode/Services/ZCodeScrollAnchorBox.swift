import Foundation
import SwiftUI

/// `ZCodeScrollAnchor` 的 `ObservableObject` 外壳。
///
/// - Important: reducer 本身是**纯值类型**，不实现 `ObservableObject`；
///   只有这个外壳发布变化，因此滚动状态更新不会波及其它观察者。
@MainActor
final class ZCodeScrollAnchorBox: ObservableObject {
    /// 当前滚动所有权状态。
    @Published private(set) var anchor = ZCodeScrollAnchor()

    /// 最近一次用户滚动方向。
    ///
    /// - Note: 供几何判定使用：往前滚时几何说了算，往回滚时方向说了算。
    private(set) var lastUserDirection: ZCodeUserScrollDirection?

    /// 处理用户滚动方向。
    ///
    /// - Important: 方向比几何更早可用：用户往回滚的那一刻，
    ///   列表正在物化新行，几何还停在底部。
    ///   靠方向立即解除跟随，才不会又被自动贴底拽回去。
    func handleUserScroll(direction: ZCodeUserScrollDirection) {
        lastUserDirection = direction
        let before = anchor.following
        anchor.handleUserScroll(direction: direction)
        guard anchor.following != before else { return }
        objectWillChange.send()
    }

    /// 处理一次滚动事件。
    func handleScroll(metrics: ZCodeScrollMetrics, source: ZCodeScrollEventSource) {
        let before = anchor.following
        anchor.handleScroll(metrics: metrics, source: source)
        guard anchor.following != before else { return }
        objectWillChange.send()
    }

    /// 恢复跟随（回到底部按钮）。
    func resumeFollowing() {
        let before = anchor.following
        anchor.resumeFollowing()
        guard anchor.following != before else { return }
        objectWillChange.send()
    }

    /// 内容变化后的动作。
    func contentChangeAction() -> ZCodeAnchorAction {
        anchor.contentChangeAction()
    }

    /// 是否应显示回到底部按钮。
    func shouldShowBackToBottom(rowCount: Int) -> Bool {
        anchor.shouldShowBackToBottom(rowCount: rowCount)
    }
}
