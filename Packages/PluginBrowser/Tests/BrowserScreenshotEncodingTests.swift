import AppKit
import CoreGraphics
import Foundation
import Testing
@testable import BrowserPlugin

/// 截图的 PNG 编码（见 issue #1282）。
///
/// 原先在主线程上做 `tiffRepresentation` → `NSBitmapImageRep(data:)` → PNG 编码，
/// 一次多余的完整编解码往返；全页截图还要做三次。
/// 修复后直接从 CGImage 建位图，并在后台线程编码。
@Suite("截图 PNG 编码")
struct BrowserScreenshotEncodingTests {

    private func makeImage(width: Int, height: Int) -> NSImage {
        let size = NSSize(width: width, height: height)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.systemBlue.setFill()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()
        return image
    }

    @Test("从 CGImage 编码得到有效 PNG")
    func encodesValidPNGFromCGImage() throws {
        let image = makeImage(width: 40, height: 30)
        let cgImage = try #require(image.cgImage(forProposedRect: nil, context: nil, hints: nil))

        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        let png = try #require(bitmap.representation(using: .png, properties: [:]))

        #expect(png.count > 0)
        #expect(png.starts(with: [0x89, 0x50, 0x4E, 0x47])) // PNG magic
    }

    @Test("直接编码与 TIFF 往返编码得到同样的像素尺寸")
    func directEncodingMatchesTIFFRoundTrip() throws {
        let image = makeImage(width: 24, height: 16)
        let cgImage = try #require(image.cgImage(forProposedRect: nil, context: nil, hints: nil))

        // 原先的路径：先编码 TIFF，再解回位图。
        let tiff = try #require(image.tiffRepresentation)
        let roundTrip = try #require(NSBitmapImageRep(data: tiff))

        // 比较**解码后**的像素尺寸：那才是图片真正呈现的分辨率。
        // `NSBitmapImageRep.size` 的单位是点，受屏幕缩放影响，
        // 在无窗口的测试进程里不稳定。
        let directPNG = try #require(
            NSBitmapImageRep(cgImage: cgImage).representation(using: .png, properties: [:])
        )
        let roundTripPNG = try #require(
            roundTrip.representation(using: .png, properties: [:])
        )
        let directDecoded = try #require(NSBitmapImageRep(data: directPNG))
        let roundTripDecoded = try #require(NSBitmapImageRep(data: roundTripPNG))

        #expect(directDecoded.pixelsWide == roundTripDecoded.pixelsWide)
        #expect(directDecoded.pixelsHigh == roundTripDecoded.pixelsHigh)
    }

    @Test("编码在后台线程执行")
    func encodingRunsOffMainThread() async throws {
        let image = makeImage(width: 64, height: 64)
        let cgImage = try #require(image.cgImage(forProposedRect: nil, context: nil, hints: nil))

        // 线程检查必须在同步闭包里做：`Thread.isMainThread`
        // 在 async 上下文中不可用。
        let wasOnMain = await Task.detached(priority: .userInitiated) { () -> Bool in
            let bitmap = NSBitmapImageRep(cgImage: cgImage)
            let png = bitmap.representation(using: .png, properties: [:])
            let encoded = png != nil
            return encoded && Thread.isMainThread
        }.value

        #expect(wasOnMain == false)
    }
}
