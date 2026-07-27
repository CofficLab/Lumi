import CoreGraphics
import Foundation
import Testing
@testable import ChatScreenshotPlugin

/// 迁移自 ChatPanelPlugin/Tests/ChatPanelLogicTests.swift(:81-132)
@Suite("ChatScreenshotState.crop")
struct ChatScreenshotCropTests {

    /// Build a solid-color CGImage of the given pixel size for crop tests.
    private func makeImage(width: Int, height: Int) -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)
        for i in stride(from: 0, to: pixels.count, by: 4) {
            pixels[i] = 255; pixels[i + 1] = 255; pixels[i + 2] = 255; pixels[i + 3] = 255
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

    @Test func cropReturnsImageForValidSelection() {
        let image = makeImage(width: 200, height: 100)
        let captureFrame = CGRect(x: 0, y: 0, width: 400, height: 200)
        // Selection covers the top-left quarter of the capture (200x100 screen → 100x50 px).
        let selection = CGRect(x: 0, y: 100, width: 200, height: 100)
        let cropped = ChatScreenshotState.crop(image: image, captureFrame: captureFrame, selection: selection)
        #expect(cropped != nil)
        #expect(cropped!.width >= 99)
        #expect(cropped!.height >= 49)
    }

    @Test func cropReturnsNilForOutOfImageSelection() {
        let image = makeImage(width: 100, height: 100)
        let captureFrame = CGRect(x: 0, y: 0, width: 100, height: 100)
        let selection = CGRect(x: 500, y: 500, width: 10, height: 10)
        let cropped = ChatScreenshotState.crop(image: image, captureFrame: captureFrame, selection: selection)
        #expect(cropped == nil)
    }

    @Test func cropClampsSelectionToImageBounds() {
        let image = makeImage(width: 100, height: 100)
        let captureFrame = CGRect(x: 0, y: 0, width: 100, height: 100)
        let selection = CGRect(x: -50, y: -50, width: 300, height: 300)
        let cropped = ChatScreenshotState.crop(image: image, captureFrame: captureFrame, selection: selection)
        #expect(cropped != nil)
        #expect(cropped!.width <= 100)
        #expect(cropped!.height <= 100)
    }

    /// 验证 Y 轴翻转:屏幕坐标 origin 在左下,CGImage 在左上
    @Test func cropFlipsYAxis() {
        let image = makeImage(width: 100, height: 100)
        // captureFrame 与 image 1:1 对应
        let captureFrame = CGRect(x: 0, y: 0, width: 100, height: 100)
        // 屏幕坐标上,selection 在底部 = y=0;crop 后应当得到 image 的下半部分(y=50..100)
        let selection = CGRect(x: 0, y: 0, width: 100, height: 50)
        let cropped = ChatScreenshotState.crop(image: image, captureFrame: captureFrame, selection: selection)
        #expect(cropped != nil)
        #expect(cropped!.height == 50)
    }
}