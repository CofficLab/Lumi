import AppKit

public extension LumiPreviewPackage {
enum PreviewFrameAlignment {
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
