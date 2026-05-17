import AppKit

public extension LumiPreviewFacade {
/// 预览帧的像素对齐工具。
///
/// 将浮点坐标矩形在指定 scale factor 下对齐到像素网格，
/// 避免因亚像素偏移导致的模糊或锯齿。
enum PreviewFrameAlignment {
    /// 对指定帧矩形进行像素对齐。
    ///
    /// 原点和尺寸分别在 scale 倍空间中向内取整/向外取整，
    /// 确保结果矩形完全覆盖原始浮点区域且与像素边界对齐。
    ///
    /// - Parameters:
    ///   - frame: 需要对齐的帧矩形。
    ///   - scale: 屏幕缩放因子（Retina 通常为 2.0）。
    /// - Returns: 像素对齐后的帧矩形。
    public static func pixelAlignedFrame(_ frame: NSRect, scale: Double) -> NSRect {
        let scale = max(scale, 1)
        let minX = floor(frame.minX * scale) / scale
        let minY = floor(frame.minY * scale) / scale
        let maxX = ceil(frame.maxX * scale) / scale
        let maxY = ceil(frame.maxY * scale) / scale
        return NSRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}

}
