import CoreText
import Foundation
import ImageIO
import KernelLumi
import Testing
@testable import OcrPlugin

@Suite("OcrImageTool")
struct OcrImageToolTests {

    // MARK: - Tool metadata

    @Test("info id is ocr_image")
    func infoId() {
        #expect(OcrImageTool.info.id == "ocr_image")
    }

    @Test("inputSchema declares path as required")
    func inputSchemaRequiresPath() {
        let tool = OcrImageTool()
        guard case .object(let props) = tool.inputSchema else {
            Issue.record("inputSchema should be an object")
            return
        }
        guard case .array(let required) = props["required"] else {
            Issue.record("inputSchema should declare a 'required' array")
            return
        }
        let requiredStrings = required.compactMap { value -> String? in
            if case .string(let s) = value { return s }
            return nil
        }
        #expect(requiredStrings.contains("path"))
    }

    // MARK: - Language resolution

    @Test("language hint maps to recognition languages", arguments: [
        ("en", ["en-US"]),
        ("EN", ["en-US"]),
        ("zh", ["zh-Hans", "en-US"]),
        ("zh-TW", ["zh-Hant", "en-US"]),
        ("ja", ["ja-JP", "en-US"]),
        ("ko", ["ko-KR", "en-US"]),
    ])
    func resolveLanguages(hint: String, expected: [String]) {
        #expect(OcrImageTool.resolveLanguages(hint) == expected)
    }

    @Test("nil language hint falls back to default")
    func resolveLanguagesDefault() {
        #expect(OcrImageTool.resolveLanguages(nil) == OcrEngine.defaultLanguages)
    }

    // MARK: - Engine error paths

    @Test("missing file throws fileNotFound")
    func missingFileThrows() async {
        let bogus = "/tmp/lumi-ocr-not-exist-\(UUID().uuidString).png"
        await #expect(throws: OcrError.self) {
            _ = try await OcrEngine.recognizeText(at: bogus, languages: ["en-US"])
        }
    }

    // MARK: - Integration: rendered text recognition

    @Test("recognizes text rendered into a PNG")
    func recognizesRenderedText() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi-ocr-\(UUID().uuidString).png")
        try renderPNG(text: "LUMI", to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let text = try await OcrEngine.recognizeText(at: url.path, languages: ["en-US"])
        #expect(text.uppercased().contains("LUMI"), "Expected recognized text to contain 'LUMI', got: \(text)")
    }

    /// 用 CoreGraphics + CoreText 在白底上渲染粗体大写文字并写入 PNG。
    /// 不依赖 AppKit 焦点机制（测试进程无图形上下文时 `NSImage.lockFocus` 会失败）。
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
                domain: "OcrPluginTests", code: 1,
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
                domain: "OcrPluginTests", code: 2,
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
                domain: "OcrPluginTests", code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Failed to render PNG"]
            )
        }
        CGImageDestinationAddImage(dest, cgImage, nil)
        guard CGImageDestinationFinalize(dest) else {
            throw NSError(
                domain: "OcrPluginTests", code: 4,
                userInfo: [NSLocalizedDescriptionKey: "Failed to finalize PNG"]
            )
        }
    }
}
