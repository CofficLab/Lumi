import CoreGraphics

/// 画布手势基线变换：连续手势在上一手势结束保存的基线上累加增量，
/// 而不是每次从零覆盖，避免第二次拖拽/缩放跳变（#326）。
struct CanvasGestureTransform: Equatable {
    static let minScale: CGFloat = 0.3
    static let maxScale: CGFloat = 3.0

    /// 上一手势结束时提交的缩放基线。
    var baseScale: CGFloat = 1.0
    /// 上一手势结束时提交的平移基线。
    var baseOffset: CGSize = .zero

    /// 当前缩放 = 基线 × 本次手势 magnification，钳到 [minScale, maxScale]。
    func scale(magnification: CGFloat) -> CGFloat {
        max(Self.minScale, min(Self.maxScale, baseScale * magnification))
    }

    /// 当前平移 = 基线 + 本次手势 translation。
    func offset(translation: CGSize) -> CGSize {
        CGSize(width: baseOffset.width + translation.width,
               height: baseOffset.height + translation.height)
    }
}