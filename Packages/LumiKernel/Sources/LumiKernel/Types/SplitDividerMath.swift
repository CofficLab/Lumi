import CoreGraphics

// MARK: - Clamp

/// 把持久化的 divider 位置 clamp 到合法区间 `[0, totalSize - dividerThickness]`。
///
/// 视图层在 `applyInitialPositionIfPossible` 与 role 切换 recheck 两处都要做这个 clamp，
/// 抽出来统一一处实现、一处测试。`totalSize <= dividerThickness` 时 `maxPosition` 退化为 0。
public struct DividerClamp: Equatable {
    /// 合法的最大 divider 位置 = `max(0, totalSize - dividerThickness)`。
    public let maxPosition: CGFloat

    /// - Parameters:
    ///   - totalSize: split view 沿分隔轴的总尺寸（HSplitView 取 width，VSplitView 取 height）。
    ///   - dividerThickness: 分隔线自身宽度。
    public init(totalSize: CGFloat, dividerThickness: CGFloat) {
        self.maxPosition = max(0, totalSize - dividerThickness)
    }

    /// 把 `position` 夹到 `[0, maxPosition]`。
    public func clamp(_ position: CGFloat) -> CGFloat {
        min(max(position, 0), maxPosition)
    }
}

// MARK: - 拖拽 vs 缩放判定

/// `classifyDividerDrag` 的判定结果。
///
/// 对应视图层 `handleDidResize` 中"本次 didResize 是什么"的状态机分支。
/// 纯函数化后可在无 AppKit 环境下覆盖每一条分支与边界。
public enum DividerDragClassification: Equatable, CustomStringConvertible {
    /// 首次观测到稳定状态，只记录基线，不做任何判断（没有"上一次"可比）。
    case firstBaseline
    /// 整体尺寸变了 → 用户在缩放窗口/外层，不是拖 divider → 跳过。
    case windowResize
    /// 尺寸不变但 divider 位置也没动（位移在阈值内）→ 无意义抖动 → 跳过。
    case jitter
    /// 处于抑制窗口内（角色切换后我们主动 setPosition 的余波）→ 只刷新基线、不持久化。
    case suppressed
    /// 尺寸不变 + divider 位置真的变了 → 用户在拖 divider → 持久化。
    case dragConfirmed(position: CGFloat)

    public var description: String {
        switch self {
        case .firstBaseline: return "firstBaseline"
        case .windowResize: return "windowResize"
        case .jitter: return "jitter"
        case .suppressed: return "suppressed"
        case .dragConfirmed(let position): return "dragConfirmed(\(position))"
        }
    }
}

/// 判定一次 didResize 属于哪一类事件。
///
/// 判定**顺序**与原 `handleDidResize` 完全一致，不可调换：
/// 1. 无基线（prevBounds / prevPosition 为 nil）→ `.firstBaseline`
/// 2. 整体尺寸变了 → `.windowResize`
/// 3. 尺寸不变但位移在 `jitterThreshold` 内 → `.jitter`
/// 4. 处于抑制窗口（`suppressionCount > 0`）→ `.suppressed`
/// 5. 其余 → `.dragConfirmed(position:)`
///
/// - Parameters:
///   - currentBounds: 本次观测到的整体尺寸。
///   - currentPosition: 本次观测到的 divider 位置。
///   - prevBounds: 上一次稳定快照的整体尺寸（首次为 nil）。
///   - prevPosition: 上一次稳定快照的 divider 位置（首次为 nil）。
///   - suppressionCount: 当前的持久化抑制计数（>0 表示处于抑制窗口内）。
///   - jitterThreshold: 判定抖动的位移阈值，位移绝对值小于它视为抖动。默认 0.5。
/// - Returns: 本次事件的分类。
public func classifyDividerDrag(
    currentBounds: CGSize,
    currentPosition: CGFloat,
    prevBounds: CGSize?,
    prevPosition: CGFloat?,
    suppressionCount: Int,
    jitterThreshold: CGFloat = 0.5
) -> DividerDragClassification {
    guard let prevBounds, let prevPosition else {
        return .firstBaseline
    }

    if currentBounds != prevBounds {
        return .windowResize
    }

    let delta = currentPosition - prevPosition
    if abs(delta) < jitterThreshold {
        return .jitter
    }

    if suppressionCount > 0 {
        return .suppressed
    }

    return .dragConfirmed(position: currentPosition)
}

/// role 切换后的位置校验：实际 divider 位置是否偏离存档值超过容差，需要重新应用。
public func shouldReapplyDivider(current: CGFloat, saved: CGFloat, tolerance: CGFloat = 1) -> Bool {
    abs(current - saved) > tolerance
}

/// 从 pane 的边界极值推算 divider 位置。
public func dividerPositionValue(index: Int, count: Int, paneMax: CGFloat, isVertical: Bool) -> CGFloat {
    guard index >= 0, index < count else { return 0 }
    _ = isVertical
    return paneMax
}
