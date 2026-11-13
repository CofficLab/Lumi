import CoreText
import Foundation
import ImageIO
import KitAgentTool
import Testing
import UniformTypeIdentifiers
@testable import PluginOcr

/// 回归 #828：ocr_image 的 UTType 闸门曾把动态类型（未知扩展名）一律当作
/// 「明确不是图片」拒绝。macOS 将 `.jif` 解析为动态 UTType（不 conform
/// `.image`），导致内容完全合法的 JPEG 在解码前就被误拒。
///
/// 修复后动态类型放行给按内容解码的 OcrEngine；只有已声明且明确非图片
/// 的类型才在闸门处拒绝。
@Suite("OcrImageTool 动态 UTType")
struct OcrImageToolDynamicTypeTests {

    private func makeDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi-ocr-jif-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test("动态 UTType 扩展名（.jif）的合法 JPEG 必须被正常识别，不得误拒")
    func dynamicExtensionJPEGIsRecognized() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let jif = directory.appendingPathComponent("valid.jif")
        try renderJPEG(text: "JIFOK", to: jif)

        let text = try await OcrImageTool().execute(arguments: [
            "path": ToolArgument(jif.path),
            "language": ToolArgument("en"),
        ])
        #expect(text.uppercased().contains("JIFOK"), "Expected 'JIFOK', got: \(text)")
    }

    @Test("已声明的非图片扩展名仍被拒绝")
    func knownNonImageExtensionStillRejected() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let textFile = directory.appendingPathComponent("note.txt")
        try "plain text".write(to: textFile, atomically: true, encoding: .utf8)

        await #expect(throws: ToolExecutionError.self) {
            _ = try await OcrImageTool().execute(arguments: [
                "path": ToolArgument(textFile.path),
            ])
        }
    }

    /// 用 CoreGraphics + CoreText 渲染粗体大写文字并写入 JPEG（public.jpeg）。
    private func renderJPEG(text: String, to url: URL) throws {
        let width = 480
        let height = 140
        guard let ctx = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw NSError(
                domain: "OcrDynamicTypeTests", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to create CGContext"]
            )
        }
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))

        let font = CTFontCreateWithName("Helvetica-Bold" as CFString, 64, nil)
        guard let attrString = CFAttributedStringCreate(
            nil, text as CFString,
            [kCTFontAttributeName: font] as CFDictionary
        ) else {
            throw NSError(
                domain: "OcrDynamicTypeTests", code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Failed to create attributed string"]
            )
        }
        let line = CTLineCreateWithAttributedString(attrString)
        let lineBounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
        ctx.textPosition = CGPoint(
            x: (CGFloat(width) - lineBounds.width) / 2,
            y: (CGFloat(height) - lineBounds.height) / 2
        )
        CTLineDraw(line, ctx)

        guard let cgImage = ctx.makeImage(),
              let dest = CGImageDestinationCreateWithURL(
                  url as CFURL, "public.jpeg" as CFString, 1, nil
              ) else {
            throw NSError(
                domain: "OcrDynamicTypeTests", code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Failed to render JPEG"]
            )
        }
        CGImageDestinationAddImage(dest, cgImage, nil)
        guard CGImageDestinationFinalize(dest) else {
            throw NSError(
                domain: "OcrDynamicTypeTests", code: 4,
                userInfo: [NSLocalizedDescriptionKey: "Failed to finalize JPEG"]
            )
        }
    }
}