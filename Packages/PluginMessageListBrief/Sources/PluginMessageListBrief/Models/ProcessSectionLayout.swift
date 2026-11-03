import CoreGraphics

/// 过程折叠区（V1 展开后的过程区）的几何规则。
///
/// 折叠区展开后可能包含很长的 LLM 回复正文与大量工具步骤。若不设上限，
/// 一次展开就能把整屏撑满、把外层列表顶出视口，用户既看不到上下文、
/// 也无法把这条 turn 滚回视野。
///
/// 因此展开区的高度封顶为**视口的一个比例**：内容短于上限时高度自适应，
/// 超出上限时进入滚动模式。
///
/// 抽出为纯函数有两个原因：
/// 1. 比例与下限都是产品参数，需要单测锁定，不该散落在视图里；
/// 2. 视图侧的滚动容器要拿「上限」与「实测高度」做比较，纯函数正好
///    提供这个比较的唯一定义处，避免两处各算一遍算出不同结果。
enum ProcessSectionLayout {
    /// 展开区高度上限占视口高度的比例。
    ///
    /// 取 60% 是「一眼能看见折叠区之外的上下文（用户消息 / 最终回复），
    /// 同时展开区本身仍能承载几屏内容」的折中。
    static let maxHeightFraction: CGFloat = 0.6

    /// 高度上限的绝对下限。
    ///
    /// 视口很矮时（窗口被拖到很矮、或分屏只剩一条缝），按比例算出的上限
    /// 会小到连一行内容都放不下，滚动区会退化成一个「几乎看不见的缝」。
    /// 因此设一个下限，保证折叠区至少能显示几行内容。
    static let minimumMaxHeight: CGFloat = 160

    /// 展开区的高度上限。
    ///
    /// - Parameters:
    ///   - viewportHeight: 消息列表视口高度。非法值（未就绪、非有限）时
    ///     返回下限，保证折叠区不会因为「视口还没量到」而完全消失。
    /// - Returns: 展开区允许占用的最大高度。
    static func maxHeight(viewportHeight: CGFloat) -> CGFloat {
        guard viewportHeight.isFinite, viewportHeight > 0 else {
            return minimumMaxHeight
        }
        return max(minimumMaxHeight, viewportHeight * maxHeightFraction)
    }

    /// 展开区在给定内容高度下实际占用的高度。
    ///
    /// 内容不超过上限时按内容自适应（不补空白）；超过上限时封顶。
    ///
    /// - Parameters:
    ///   - contentHeight: 折叠区内容的实测高度；`nil` 表示**尚未测量**。
    ///   - maxHeight: 由 ``maxHeight(viewportHeight:)`` 算出的上限。
    /// - Returns: 展开区应当占用的高度。
    static func resolvedHeight(contentHeight: CGFloat?, maxHeight: CGFloat) -> CGFloat {
        guard let contentHeight, contentHeight.isFinite, contentHeight > 0 else {
            // 尚未测量（或量到非法值）时先按上限占位：宁可让滚动区占满上限
            // 并出现滚动条，也不要塌成 0 高度让内容凭空消失。实测值到达后
            // 会立刻收敛到真实高度。
            return maxHeight
        }
        return min(contentHeight, maxHeight)
    }

    /// 内容高度是否超出了上限（即需要进入滚动模式）。
    ///
    /// - Parameters:
    ///   - contentHeight: 折叠区内容的实测高度。
    ///   - maxHeight: 展开区的高度上限。
    /// - Returns: 内容超出上限时为 `true`。
    static func isOverflowing(contentHeight: CGFloat, maxHeight: CGFloat) -> Bool {
        guard contentHeight.isFinite, maxHeight.isFinite else { return false }
        return contentHeight > maxHeight
    }
}
