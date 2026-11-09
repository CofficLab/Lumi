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

/// 滚动几何快照。
struct ZCodeScrollMetrics: Equatable {
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
        following = Self.isAtBottom(metrics)
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
