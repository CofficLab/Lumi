import CoreGraphics
import Foundation

/// 滚动事件的来源。
///
/// - Important: 区分来源是 V4 滚动所有权的核心。只有 `.user` 代表**真实的
///   用户滚动意图**，程序化贴底与布局变化只更新几何账目，不得改变 following。
enum ZCodeScrollEventSource: Equatable {
    /// 真实用户输入（滚轮、触摸、键盘、滚动条拖动）。
    case user
    /// 程序化滚动（贴底、锚点回钉、翻页锚定）。
    case programmatic
    /// 布局变化（文档变高、异步测高、折叠、resize）。
    case layout
}

/// 用户滚动的方向。
enum ZCodeUserScrollDirection: Equatable {
    /// 内容向上移动（视口往下走，看到更晚的内容）。
    case forward
    /// 内容向下移动（视口往上走，看到更早的内容）。
    case backward
}

/// 滚动几何快照。
struct ZCodeScrollMetrics: Equatable {
    /// 用户滚动的方向；nil 表示本次事件不是用户滚动。
    var userDirection: ZCodeUserScrollDirection?

    /// 滚动偏移（scrollTop）。
    var offsetY: CGFloat
    /// 可视区高度。
    var visibleHeight: CGFloat
    /// 内容总高度。
    var documentHeight: CGFloat

    /// 几何是否有限且可用。
    ///
    /// 非有限值（NaN / infinity）或负的可视高度都视为「不可用」，
    /// 此时不得让状态发生任何翻转。
    var areFiniteAndUsable: Bool {
        offsetY.isFinite
            && visibleHeight.isFinite
            && documentHeight.isFinite
            && visibleHeight >= 0
            && documentHeight >= 0
    }
}

/// 内容变化后应当执行的动作。
enum ZCodeAnchorAction: Equatable {
    /// 贴底（跟随中）。
    case stickToBottom
    /// 保持当前阅读位置（已脱离跟随）。
    case hold
}

/// V4（ZCode）滚动所有权 reducer。
///
/// 基准是 ZCode 3.15.1 的 `packages/ui/src/v4/timelineScrollAnchor.ts`：
///
/// - 底部容差固定 48px：`max(0, contentHeight - viewportHeight - scrollTop) <= 48` 视为底部。
/// - `following` 表示**用户滚动权**，不是瞬时几何快照。
/// - 只有真实用户滚动输入可以改变 following；程序化 / 布局事件只更新几何账目。
/// - following 时内容增长贴底；detached 时保持阅读位置并显示回底按钮。
///
/// - Important: 本 reducer **独立于** V3 的 `BottomEdgeEvaluator`
///   （enter 24 / leave 96）。V4 使用自己的 48 阈值，不得全局改动 V3 的数值。
struct ZCodeScrollAnchor: Equatable {
    /// 离底判定容差。
    static let bottomTolerance: CGFloat = 48

    /// 当前是否跟随底部（用户滚动权）。
    var following = true

    // MARK: - 几何

    /// 距底部的剩余可滚动距离；内容不足一屏时为 0。
    static func distanceToBottom(_ metrics: ZCodeScrollMetrics) -> CGFloat {
        guard metrics.areFiniteAndUsable else { return 0 }
        return max(0, metrics.documentHeight - metrics.visibleHeight - metrics.offsetY)
    }

    /// 是否在底部（距底不超过容差）。
    static func isAtBottom(_ metrics: ZCodeScrollMetrics) -> Bool {
        distanceToBottom(metrics) <= bottomTolerance
    }

    // MARK: - 状态变更

    /// 处理一次滚动事件。
    ///
    /// - Important: 只有 `.user` 来源且几何有效时才改变 `following`。
    ///   程序化贴底与布局变化必须原样保留用户意图。
    mutating func handleScroll(metrics: ZCodeScrollMetrics, source: ZCodeScrollEventSource) {
        guard source == .user, metrics.areFiniteAndUsable else { return }

        // Important: 用户**往回滚**时立刻解除跟随，不等几何稳定。
        //
        //   为什么要先看方向再看几何：用户往回看时，列表会顺带物化更多行，
        //   文档高度随之增长；若此时自动贴底把用户拽回底部，
        //   几何就永远停在底部 —— 用户「往上滚了却还在底部」，
        //   而 `following` 也无从解除。
        //
        //   方向是用户意图的**直接**表达，比「离底多远」更早、更可靠。
        if metrics.userDirection == .backward {
            following = false
            return
        }

        // Important: 几何判定**不得**无条件把已解除的跟随恢复回来。
        //
        //   用户往回滚时，列表正在物化新行，文档高度跟着涨，
        //   此刻算出来的「离底距离」仍是 0 —— 用它恢复跟随，
        //   等于把用户刚做的「往上滚」直接吃掉。
        //
        //   因此分两种情况：
        //   - 用户**往前**滚（`userDirection == .forward`）：几何说了算。
        //     用户主动往下滚回底部，就是想回到跟随状态。
        //   - 方向未知（滚动条拖动等）：只在几何**明确**显示已回到底部
        //     （距离已很小且非 0）时才恢复；否则保持脱离。
        // Important: 几何判定在「已脱离跟随」时的语义。
        //
        //   - 离底**很远**（distance > 容差）：保持脱离。用户还在上面看。
        //   - 离底**在容差内**：恢复跟随。用户确实回到底部了。
        //
        //   唯一的例外是「用户往回滚」这一刻：列表正在物化新行，
        //   文档高度跟着涨，此刻算出来的距离仍是 0。
        //   若据此恢复跟随，等于把用户刚做的「往上滚」直接吃掉。
        //   所以往回滚时**一律**保持脱离，由方向事件单独决定。
        if !following {
            let distance = Self.distanceToBottom(metrics)
            if metrics.userDirection == .backward {
                return
            }
            guard distance <= Self.bottomTolerance else { return }
        }

        following = Self.isAtBottom(metrics)
    }

    /// 处理用户滚动方向。
    ///
    /// - Important: 往回滚立即解除跟随；往前滚**不**恢复跟随 ——
    ///   恢复跟随必须由几何判定（回到 48px 内）或用户点击
    ///   「回到底」按钮，否则用户只是往下挪了一点就被强行拽到底。
    mutating func handleUserScroll(direction: ZCodeUserScrollDirection) {
        guard direction == .backward else { return }
        following = false
    }

    /// 内容变化（新行追加 / 流式 delta 撑高 / 动态测高修正）后的动作。
    func contentChangeAction() -> ZCodeAnchorAction {
        following ? .stickToBottom : .hold
    }

    /// 用户点击「回到底部」按钮：恢复跟随。
    mutating func resumeFollowing() {
        following = true
    }

    /// 「回到底部」按钮是否可见：仅在脱离跟随且确实存在内容时展示。
    func shouldShowBackToBottom(rowCount: Int) -> Bool {
        !following && rowCount > 0
    }
}
