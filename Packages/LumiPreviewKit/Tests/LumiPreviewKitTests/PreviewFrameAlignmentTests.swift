import AppKit
import Testing
@testable import LumiPreviewKit

@Suite("PreviewFrameAlignment")
struct PreviewFrameAlignmentTests {

    @Test("scale 2 时按半像素边界对齐")
    func alignsToHalfPointsAtScale2() {
        let frame = NSRect(x: 10.24, y: 20.26, width: 300.24, height: 200.24)
        let aligned = LumiPreviewPackage.PreviewFrameAlignment.pixelAlignedFrame(frame, scale: 2)

        #expect(aligned.minX == 10.0)
        #expect(aligned.minY == 20.0)
        #expect(aligned.maxX == 310.5)
        #expect(aligned.maxY == 220.5)
    }

    @Test("scale 小于 1 时按 1x 处理")
    func clampsScaleBelowOne() {
        let frame = NSRect(x: 10.2, y: 20.2, width: 300.2, height: 200.2)
        let aligned = LumiPreviewPackage.PreviewFrameAlignment.pixelAlignedFrame(frame, scale: 0.5)

        #expect(aligned.minX == 10.0)
        #expect(aligned.minY == 20.0)
        #expect(aligned.maxX == 311.0)
        #expect(aligned.maxY == 221.0)
    }

    @Test("已经像素对齐的 frame 保持不变")
    func keepsAlreadyAlignedFrame() {
        let frame = NSRect(x: 12.5, y: 18.0, width: 100.5, height: 50.0)
        let aligned = LumiPreviewPackage.PreviewFrameAlignment.pixelAlignedFrame(frame, scale: 2)

        #expect(aligned == frame)
    }
}
