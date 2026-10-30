import CoreGraphics

/// 「内容底沿是否已到视口底」的纯几何判定器。
///
/// 从 `TrackerView.reevaluate()` 中抽出的无副作用值类型，供单测直接覆盖迟滞带、
/// 退化几何（非有限值 / 零可视高度）与阈值选择等分支；`TrackerView` 只负责
/// 从 `NSScrollView` 取数并把结果回调出去。
///
/// 迟滞规则（与 `MessageListScrollCoordinator` 的两个阈值配套）：
/// - 上一次在底部 → 用更宽容的 `leaveTolerance` 判定离开；
/// - 上一次不在底部 → 用更严格的 `enterTolerance` 判定回到。
///
/// 这样在容差边界反复抖动时不会来回翻转 `onChange`。
struct BottomEdgeEvaluator: Equatable {
    /// 不在底部时，判定「回到底部」的容差。刻意比离开容差严格，构成迟滞带。
    static let enterTolerance: CGFloat = 24
    /// 已在底部时，判定「离开底部」的容差。比进入容差宽容。
    static let leaveTolerance: CGFloat = 96

    /// 几何无效时返回的判定结果 —— 调用方应直接忽略，不视为状态变化。
    struct Result: Equatable {
        /// 判定出的「是否在底部」。
        let atBottom: Bool
        /// 是否应向宿主回调。仅在 `atBottom` 相对上次状态发生翻转时为 true。
        let shouldNotify: Bool
    }

    let enterTolerance: CGFloat
    let leaveTolerance: CGFloat

    init(
        enterTolerance: CGFloat = Self.enterTolerance,
        leaveTolerance: CGFloat = Self.leaveTolerance
    ) {
        self.enterTolerance = enterTolerance
        self.leaveTolerance = leaveTolerance
    }

    /// 根据当前几何与上次判定结果计算新的「是否在底部」。
    ///
    /// - Parameters:
    ///   - documentHeight: `documentView.bounds.height`。
    ///   - visibleHeight: `clipView.bounds.height`（可视区高度）。
    ///   - offsetY: `clipView.bounds.origin.y`（当前滚动偏移）。
    ///   - previousAtBottom: 上一次判定的结果。
    /// - Returns: `nil` 表示几何不可用（非有限值、可视高度为 0、文档高度异常大），
    ///   调用方应保持原状态不做任何回调。
    func evaluate(
        documentHeight: CGFloat,
        visibleHeight: CGFloat,
        offsetY: CGFloat,
        previousAtBottom: Bool
    ) -> Result? {
        guard documentHeight.isFinite,
              visibleHeight.isFinite,
              documentHeight < 10_000_000,
              visibleHeight > 0 else { return nil }

        let distance = documentHeight - (offsetY + visibleHeight)
        let tolerance = previousAtBottom ? leaveTolerance : enterTolerance
        let atBottom = distance <= tolerance

        return Result(atBottom: atBottom, shouldNotify: atBottom != previousAtBottom)
    }
}
