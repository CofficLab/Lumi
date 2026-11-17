import CoreGraphics
import Foundation
import Testing
@testable import PluginChatScreenshot

@Suite("截图坐标系转换")
struct ScreenCaptureCoordinateTests {
    /// 生成指定尺寸的 CGImage：前 `bandRows` 行为黑色，其余为白色。
    private func makeImageWithTopBand(width: Int, height: Int, bandRows: Int) -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 255, count: bytesPerRow * height)
        for row in 0..<min(bandRows, height) {
            for col in 0..<(width * 4) {
                pixels[row * bytesPerRow + col] = col % 4 == 3 ? 255 : 0
            }
        }
        let provider = CGDataProvider(data: Data(bytes: &pixels, count: pixels.count) as CFData)!
        return CGImage(
            width: width, height: height,
            bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
        )!
    }

    private func isBlack(_ pixel: (r: UInt8, g: UInt8, b: UInt8)) -> Bool {
        pixel.r == 0 && pixel.g == 0 && pixel.b == 0
    }

    @Test("原点在主屏内的单屏 union 换算后保持不变（#646）")
    func singleDisplayAtOriginStaysUnchanged() {
        let rect = CGRect(x: 0, y: 0, width: 1440, height: 900)
        #expect(ScreenCaptureService.displaySpaceRect(fromAppKit: rect, primaryDisplayHeight: 900) == rect)
    }

    @Test("副屏在主屏上方时 union 转为负 y 的显示空间矩形（回归 #829 示例）")
    func secondaryAboveFlipsUnionToNegativeY() {
        // 主屏 (0,0,1440,900) + 副屏 (0,900,1440,900) 的 AppKit union。
        let union = CGRect(x: 0, y: 0, width: 1440, height: 1800)
        #expect(
            ScreenCaptureService.displaySpaceRect(fromAppKit: union, primaryDisplayHeight: 900)
                == CGRect(x: 0, y: -900, width: 1440, height: 1800)
        )
    }

    @Test("副屏在主屏下方时 union 转为顶部对齐主屏顶端的显示空间矩形（回归 #646）")
    func secondaryBelowAlignsTopToPrimaryTop() {
        // 主屏 (0,0,1440,900) + 副屏 (0,-900,1440,900) 的 AppKit union。
        let union = CGRect(x: 0, y: -900, width: 1440, height: 1800)
        #expect(
            ScreenCaptureService.displaySpaceRect(fromAppKit: union, primaryDisplayHeight: 900)
                == CGRect(x: 0, y: 0, width: 1440, height: 1800)
        )
    }

    @Test("带纵向偏移的横向双屏 union 只翻转 y 区间，x 区间不变（#646）")
    func keepsXAndFlipsOnlyY() {
        let union = CGRect(x: -1200, y: 100, width: 3600, height: 800)
        #expect(
            ScreenCaptureService.displaySpaceRect(fromAppKit: union, primaryDisplayHeight: 900)
                == CGRect(x: -1200, y: 0, width: 3600, height: 800)
        )
    }

    @Test("换算后的抓取区域与 AppKit 选区裁剪在同一桌面区域上配对（回归 #646）")
    func captureRectAndCropPairOnSameDesktopRegion() {
        // 双屏纵向堆叠的 AppKit union 与换算后的显示空间抓取矩形。
        let appKitUnion = CGRect(x: 0, y: 0, width: 1440, height: 1800)
        let captureRect = ScreenCaptureService.displaySpaceRect(fromAppKit: appKitUnion, primaryDisplayHeight: 900)
        #expect(captureRect == CGRect(x: 0, y: -900, width: 1440, height: 1800))

        // 模拟抓取结果：显示空间矩形 (0,-900,1440,1800) 的位图，行 0 是 union
        // 顶部（AppKit y 1800），顶部 400 行是黑色。按配对不变量，黑色条带对应
        // AppKit y 1400...1800（上方副屏的下半部分）。
        let image = makeImageWithTopBand(width: 1440, height: 1800, bandRows: 400)

        // 在副屏内选区（AppKit y 1500...1700），裁剪必须完全落在黑色条带内。
        let selection = CGRect(x: 0, y: 1500, width: 1440, height: 200)
        let cropped = ChatScreenshotState.crop(image: image, captureFrame: appKitUnion, selection: selection)
        let result = try! #require(cropped)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var buffer = [UInt8](repeating: 0, count: result.width * result.height * 4)
        let context = CGContext(
            data: &buffer, width: result.width, height: result.height,
            bitsPerComponent: 8, bytesPerRow: result.width * 4, space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.draw(result, in: CGRect(x: 0, y: 0, width: result.width, height: result.height))
        for i in stride(from: 0, to: buffer.count, by: 4) {
            #expect(isBlack((buffer[i], buffer[i + 1], buffer[i + 2])))
        }
    }
}
