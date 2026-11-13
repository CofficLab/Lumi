import CoreText
import Foundation
import ImageIO
import KitAgentTool
import Testing
@testable import PluginOcr

/// 回归 #827：ocr_image 曾对 path 先做 whitespace trim 再访问文件。
/// macOS 文件名可以合法地以空格结尾：trim 会把存在的文件误报为不存在，
/// 若 trim 后的同名文件也存在，还会静默识别另一张图片。
///
/// 修复后 trim 只用于判断参数是否为空；存在性检查与 OCR 读取必须使用
/// 调用方给出的原始路径。
@Suite("OcrImageTool 路径保真")
struct OcrImageToolPathTrimTests {

    private func makeDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi-ocr-path-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test("尾随空格的合法文件名必须被正常识别，不得误报不存在")
    func trailingSpaceFilenameIsRecognized() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let spaced = directory.appendingPathComponent("valid.png ")
        try renderPNG(text: "SPACED", to: spaced)

        let text = try await OcrImageTool().execute(arguments: [
            "path": ToolArgument(spaced.path),
            "language": ToolArgument("en"),
        ])
        #expect(text.uppercased().contains("SPACED"), "Expected 'SPACED', got: \(text)")
    }

    @Test("同名文件共存时必须读取调用方指定的原始路径，不得读错文件")
    func originalPathWinsOverTrimmedSibling() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let spaced = directory.appendingPathComponent("valid.png ")
        let plain = directory.appendingPathComponent("valid.png")
        try renderPNG(text: "SPACED", to: spaced)
        try renderPNG(text: "PLAIN", to: plain)

        let text = try await OcrImageTool().execute(arguments: [
            "path": ToolArgument(spaced.path),
            "language": ToolArgument("en"),
        ])
        #expect(text.uppercased().contains("SPACED"), "Expected 'SPACED', got: \(text)")
        #expect(!text.uppercased().contains("PLAIN"), "Must not read the trimmed sibling, got: \(text)")
    }

    @Test("纯空白路径仍按缺参拒绝")
    func whitespaceOnlyPathStillRejected() async throws {
        await #expect(throws: ToolExecutionError.self) {
            _ = try await OcrImageTool().execute(arguments: [
                "path": ToolArgument("   "),
            ])
        }
    }

    /// 用 CoreGraphics + CoreText 在白底上渲染粗体大写文字并写入 PNG。
    /// 与 OcrImageToolTests.renderPNG 同一手法：不依赖 AppKit 焦点机制。
    private func renderPNG(text: String, to url: URL) throws {
        let width = 480
        let height = 140
        guard let ctx = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw NSError(
                domain: "OcrPathTrimTests", code: 1,
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
                domain: "OcrPathTrimTests", code: 2,
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
                  url as CFURL, "public.png" as CFString, 1, nil
              ) else {
            throw NSError(
                domain: "OcrPathTrimTests", code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Failed to render PNG"]
            )
        }
        CGImageDestinationAddImage(dest, cgImage, nil)
        guard CGImageDestinationFinalize(dest) else {
            throw NSError(
                domain: "OcrPathTrimTests", code: 4,
                userInfo: [NSLocalizedDescriptionKey: "Failed to finalize PNG"]
            )
        }
    }
}