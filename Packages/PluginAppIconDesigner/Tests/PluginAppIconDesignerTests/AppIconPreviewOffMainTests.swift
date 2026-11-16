import AppKit
import CoreGraphics
import ImageIO
import Testing

@testable import PluginAppIconDesigner

/// 回归 issue #1289：preview_icon/review_icon 的 PNG 压缩必须能在后台线程执行，
/// 主 actor 只负责 ImageRenderer 栅格化，不再被整条 rasterize-then-encode 管线占用。
@Suite("AppIconExportService off-main preview encode")
struct AppIconPreviewOffMainTests {

    @Test("preview PNG encodes off the main actor from a main-actor CGImage capture")
    @MainActor
    func encodesOffMain() async throws {
        let document = IconDocument(title: "Off Main", width: 512, height: 512)
        let cgImage = try AppIconExportService().renderPreviewCGImage(document: document, pixelSize: 256)
        #expect(cgImage.width == 256)
        #expect(cgImage.height == 256)

        let data = try await Task.detached(priority: .userInitiated) {
            try AppIconExportService.encodePNG(cgImage: cgImage)
        }.value

        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        #expect(CGImageSourceGetCount(source) == 1)
        let decoded = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(decoded.width == 256)
        #expect(decoded.height == 256)
    }
}