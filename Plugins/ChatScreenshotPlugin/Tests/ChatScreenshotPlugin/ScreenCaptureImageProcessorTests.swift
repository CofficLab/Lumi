import CoreGraphics
import Foundation
import Testing
@testable import ChatScreenshotPlugin

@Suite("ScreenCaptureImageProcessor")
@MainActor
struct ScreenCaptureImageProcessorTests {

    /// 构造一张指定尺寸的纯色 CGImage
    private func makeImage(width: Int, height: Int) -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)
        for i in stride(from: 0, to: pixels.count, by: 4) {
            pixels[i] = 200; pixels[i + 1] = 200; pixels[i + 2] = 200; pixels[i + 3] = 255
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

    @Test("小图不会被缩放")
    func downscaleReturnsOriginalForSmallImage() {
        let image = makeImage(width: 800, height: 600)
        let result = ScreenCaptureImageProcessor.downscale(image, maxDimension: 1920)
        #expect(result.width == 800)
        #expect(result.height == 600)
    }

    @Test("大图按长边等比缩放")
    func downscaleReturnsScaledForLargeImage() {
        let image = makeImage(width: 3840, height: 2160)
        let result = ScreenCaptureImageProcessor.downscale(image, maxDimension: 1920)
        #expect(result.width == 1920)
        #expect(result.height == 1080)  // 2160 * (1920/3840) = 1080
    }

    @Test("attachment 输出 JPEG 且长边受限")
    func makeAttachmentProducesJPEGUnderSizeLimit() {
        let image = makeImage(width: 4000, height: 3000)
        let attachment = ScreenCaptureImageProcessor.makeAttachment(from: image)
        #expect(attachment.mimeType == "image/jpeg")
        #expect(!attachment.base64Data.isEmpty)
        // base64 长度 / 1.37 ≈ 字节数;1920 长边 JPEG 大约 < 500KB
        let base64Len = attachment.base64Data.count
        let approxBytes = Double(base64Len) * 0.75
        #expect(approxBytes < 700_000, "JPEG output should be under 700KB, got \(Int(approxBytes)) bytes")
        #expect(attachment.fileName?.hasSuffix(".jpg") == true)
    }
}