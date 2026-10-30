import Foundation
import CoreGraphics

/// 消息列表底部收敛所需的最小几何能力。
///
/// ## 为什么存在这个协议
///
/// `settleBottom` 的收敛判据（连续 N 帧 `documentHeight` / `visibleHeight` /
/// `offsetY` 稳定）是消息列表切换会话时最容易出回归的部分，但此前它直接依赖
/// `ScrollViewBottomController`（内部持有真实 `NSScrollView`）与 `ScrollViewProxy`。
/// 两者在单元测试里都无法构造，**该逻辑因此从未被任何测试覆盖过** —— 回归得以
/// 溜进主干。
///
/// 这里把「读取一次几何快照并钉底」收窄为协议，`ScrollViewBottomController`
/// 继续实现它。测试用可控的假实现即可确定性地驱动收敛循环，不再依赖真实窗口。
///
/// - Note: 这是纯抽象提取，不改变任何运行时行为。
@MainActor
protocol MessageListBottomGeometry: AnyObject {
    /// 控制器是否已绑定到真实滚动视图。
    ///
    /// 未绑定时 `pinToBottom()` 返回 nil，`settleBottom` 会立即放弃收敛
    /// —— 这正是「切换会话时 List 刚重建、tracker 尚未 attach」的窗口。
    var isAttached: Bool { get }

    /// 钉住 document 底边并返回当前几何快照；不可用时返回 nil。
    func pinToBottom() -> ScrollViewBottomController.Snapshot?
}

extension ScrollViewBottomController: MessageListBottomGeometry {}


/// 底部判定的**唯一实现**。
///
/// 原先这段规则内联在 `ScrollViewBottomTracker.reevaluate()` 中且为 private，
/// 只能靠真实视图树触发，因而长期零覆盖。抽为纯函数后：
/// - 生产路径（tracker）与测试共用同一实现，不存在「测试复制一份」导致的漂移；
/// - 迟滞带这种易错的边界条件可以被精确断言。
enum BottomDecision {
    /// 由几何量计算「是否在底部」。
    ///
    /// 迟滞：已在底部时用更宽容的离开阈值，不在底部时用更严格的进入阈值，
    /// 避免在容差边界抖动时反复翻转 `onChange`。
    ///
    /// - Returns: 判定结果；几何不可用时返回 nil（调用方应放弃本次判定）。
    static func evaluate(
        documentHeight: CGFloat,
        visibleHeight: CGFloat,
        offsetY: CGFloat,
        lastAtBottom: Bool,
        enterTolerance: CGFloat,
        leaveTolerance: CGFloat
    ) -> Bool? {
        guard documentHeight.isFinite, visibleHeight.isFinite,
              documentHeight < 10_000_000, visibleHeight > 0 else { return nil }
        let distance = documentHeight - (offsetY + visibleHeight)
        let tolerance = lastAtBottom ? leaveTolerance : enterTolerance
        return distance <= tolerance
    }
}
