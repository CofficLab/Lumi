import CoreGraphics
import SwiftUI

/// V4（ZCode）响应式布局常量与计算。
///
/// 基准是 ZCode 3.15.1：
/// - 内容列宽：`packages/ui/src/v4/conversationLayout.ts` 的
///   `w-full @min-[864px]/conversation:w-[calc(100%_-_6rem)] @min-[864px]/conversation:max-w-4xl
///   @min-[1280px]/conversation:w-[calc(100%_-_24rem)] @min-[1280px]/conversation:max-w-6xl`；
/// - turn 间距：`packages/ui/src/v4/ConversationTurnGroup.tsx` 的
///   `px-4 @md/conversation:px-6 pb-5` + `pt-14` / `pt-0` + `gap-5`；
/// - 用户气泡：`packages/ui/src/v4/ConversationUserInputBubble.tsx` 的
///   `rounded-xl rounded-tr-xs … px-4 py-3 … @min-[624px]/conversation:max-w-xl`。
///
/// - Important: 所有宽度都基于**聊天容器宽度**，不是窗口宽度。
enum ZCodeConversationLayout {

    // MARK: - 内容列

    /// 内容列宽度。
    ///
    /// | 聊天容器宽度 `c` | 常规内容列宽 |
    /// |---|---|
    /// | `c < 864` | `c` |
    /// | `864 ≤ c < 1280` | `min(c - 96, 896)` |
    /// | `c ≥ 1280` | `min(c - 384, 1152)` |
    static func contentWidth(for container: CGFloat) -> CGFloat {
        guard container.isFinite, container > 0 else { return 0 }
        switch container {
        case ..<864:
            return container
        case ..<1280:
            return min(container - 96, 896)
        default:
            return min(container - 384, 1152)
        }
    }

    // MARK: - turn 间距

    /// turn 内的水平 padding：容器 `< 448` 为 16，`≥ 448` 为 24。
    static func turnHorizontalPadding(for container: CGFloat) -> CGFloat {
        container >= 448 ? 24 : 16
    }

    /// turn 内的垂直间距。
    struct TurnSpacing: Equatable {
        /// 顶部间距。
        let top: CGFloat
        /// 底部间距。
        let bottom: CGFloat
    }

    /// turn 的垂直间距。
    ///
    /// - 普通含用户气泡的 turn：顶部 56、底部 20。
    /// - 没有可见用户气泡的工作/通知型 turn：顶部 0、底部 20，
    ///   避免与上一 turn 的 20 叠加成 76 的空白。
    static func turnSpacing(hasVisibleUserBubble: Bool) -> TurnSpacing {
        TurnSpacing(
            top: hasVisibleUserBubble ? 56 : 0,
            bottom: 20
        )
    }

    /// turn 一级内容间距。
    static let primarySpacing: CGFloat = 20

    /// 连续 reasoning / tool 等工作项之间的间距。
    static let workItemSpacing: CGFloat = 16

    // MARK: - 用户气泡

    /// 用户气泡最大宽度。
    ///
    /// - 容器 `< 624`：气泡最大可用全宽。
    /// - 容器 `≥ 624`：最大 576，同时仍受内容列内宽约束。
    static func userBubbleMaxWidth(containerWidth: CGFloat, contentWidth: CGFloat) -> CGFloat {
        let capped: CGFloat = containerWidth >= 624 ? 576 : containerWidth
        return min(capped, contentWidth)
    }

    /// 用户气泡圆角：四角 12，右上角 2。
    static let userBubbleCornerRadii = UnevenRoundedRectangleCorners(
        topLeading: 12,
        bottomLeading: 12,
        bottomTrailing: 12,
        topTrailing: 2
    )

    /// 用户气泡水平内边距。
    static let userBubbleHorizontalPadding: CGFloat = 16

    /// 用户气泡垂直内边距。
    static let userBubbleVerticalPadding: CGFloat = 12

    /// 长文可见高度。
    static let longTextVisibleHeight: CGFloat = 120

    /// 长文是否需要折叠。
    ///
    /// 可见高度 120，overflow tolerance 1：实测 120 / 121 不折叠，122 折叠。
    static func shouldCollapse(contentHeight: CGFloat) -> Bool {
        guard contentHeight.isFinite else { return false }
        return contentHeight > longTextVisibleHeight + 1
    }
}

/// 不对称圆角（四角可分别指定）。
///
/// SwiftUI 没有内置的「四角独立圆角」类型，需要用 `UnevenRoundedRectangle` 表达。
struct UnevenRoundedRectangleCorners: Equatable {
    let topLeading: CGFloat
    let bottomLeading: CGFloat
    let bottomTrailing: CGFloat
    let topTrailing: CGFloat

    /// 转换为 SwiftUI 的 `UnevenRoundedRectangle`。
    var shape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: topLeading,
            bottomLeadingRadius: bottomLeading,
            bottomTrailingRadius: bottomTrailing,
            topTrailingRadius: topTrailing,
            style: .continuous
        )
    }
}
