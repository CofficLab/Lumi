import Foundation
import Testing
@testable import BrowserPlugin

/// 回归覆盖 issue #1060：整页截图不能只限制高度。
@Suite("Browser 整页截图边界")
struct BrowserScreenshotGeometryTests {

    @Test("极宽页面被钳制到单边上限")
    func clampsExtremelyWidePages() {
        let geometry = BrowserScreenshotGeometry.fitted(width: 200_000, height: 300)

        #expect(geometry.rect.width == BrowserScreenshotGeometry.maxDimension)
        #expect(geometry.rect.height == 300)
        #expect(geometry.outputScale == 1)
    }

    @Test("超高页面同样被钳制")
    func clampsExtremelyTallPages() {
        let geometry = BrowserScreenshotGeometry.fitted(width: 800, height: 500_000)

        #expect(geometry.rect.height == BrowserScreenshotGeometry.maxDimension)
        #expect(geometry.rect.width == 800)
    }

    @Test("超过总像素预算时按比例降采样并保持长宽比")
    func downscalesBeyondPixelBudget() {
        let geometry = BrowserScreenshotGeometry.fitted(width: 200_000, height: 200_000)

        #expect(geometry.rect.width == BrowserScreenshotGeometry.maxDimension)
        #expect(geometry.rect.height == BrowserScreenshotGeometry.maxDimension)
        #expect(geometry.outputScale < 1)

        let width = geometry.rect.width * geometry.outputScale
        let height = geometry.rect.height * geometry.outputScale
        #expect(abs(width - height) < 0.001, "正方形内容的输出仍应是正方形")
        #expect(width * height <= BrowserScreenshotGeometry.maxPixels + 1)
    }

    @Test("常规页面不缩放")
    func leavesNormalPagesUntouched() {
        let geometry = BrowserScreenshotGeometry.fitted(width: 1280, height: 720)

        #expect(geometry.rect == CGRect(x: 0, y: 0, width: 1280, height: 720))
        #expect(geometry.outputScale == 1)
        #expect(geometry.snapshotWidth(scale: geometry.outputScale) == 1280)
    }

    @Test("非法尺寸至少保留 1 点")
    func clampsNonPositiveSizes() {
        let geometry = BrowserScreenshotGeometry.fitted(width: 0, height: -10)

        #expect(geometry.rect.width == 1)
        #expect(geometry.rect.height == 1)
    }

    @Test("降采样后的输出像素不超过预算")
    func outputPixelsStayWithinBudget() {
        for (width, height) in [(16_000.0, 16_000.0), (100_000.0, 16_000.0), (3_000.0, 16_000.0)] {
            let geometry = BrowserScreenshotGeometry.fitted(width: width, height: height)
            #expect(geometry.outputPixels <= BrowserScreenshotGeometry.maxPixels + 1)
        }
    }
}
