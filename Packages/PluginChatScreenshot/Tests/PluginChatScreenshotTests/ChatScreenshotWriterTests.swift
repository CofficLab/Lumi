import CoreGraphics
import Foundation
import Testing
@testable import PluginChatScreenshot

// MARK: - 夹具

/// 生成纯色 CGImage，供编码与缩放测试使用。
private func makeImage(width: Int, height: Int) -> CGImage {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bytesPerRow = width * 4
    var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)
    for i in stride(from: 0, to: pixels.count, by: 4) {
        pixels[i] = 255
        pixels[i + 1] = 255
        pixels[i + 2] = 255
        pixels[i + 3] = 255
    }
    let provider = CGDataProvider(data: Data(bytes: &pixels, count: pixels.count) as CFData)!
    return CGImage(
        width: width,
        height: height,
        bitsPerComponent: 8,
        bitsPerPixel: 32,
        bytesPerRow: bytesPerRow,
        space: colorSpace,
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
        provider: provider,
        decode: nil,
        shouldInterpolate: false,
        intent: .defaultIntent
    )!
}

// MARK: - 缩放

@Suite("截图文件写入器缩放")
@MainActor
struct ScreenshotDownscaleTests {

    @Test("小于上限的图保持原尺寸")
    func keepsSmallImage() {
        let image = makeImage(width: 100, height: 50)

        let scaled = ScreenshotFileWriter.downscale(image, maxDimension: 1920)

        #expect(scaled.width == 100)
        #expect(scaled.height == 50)
    }

    @Test("超过上限的图按长边等比缩小")
    func scalesDownLongestSide() {
        let image = makeImage(width: 4000, height: 2000)

        let scaled = ScreenshotFileWriter.downscale(image, maxDimension: 1000)

        #expect(max(scaled.width, scaled.height) == 1000)
        #expect(scaled.width == 1000)
        #expect(scaled.height == 500)
    }

    @Test("上限非正时不做缩放")
    func skipsScalingForNonPositiveLimit() {
        let image = makeImage(width: 4000, height: 2000)

        let scaled = ScreenshotFileWriter.downscale(image, maxDimension: 0)

        #expect(scaled.width == 4000)
        #expect(scaled.height == 2000)
    }

    @Test("竖图按长边缩放")
    func scalesPortraitImage() {
        let image = makeImage(width: 1000, height: 4000)

        let scaled = ScreenshotFileWriter.downscale(image, maxDimension: 500)

        #expect(scaled.height == 500)
        #expect(scaled.width == 125)
    }

    @Test("默认上限与 JPEG 质量固定")
    func defaultConstants() {
        #expect(ScreenshotFileWriter.maxDimension == 1920)
        #expect(ScreenshotFileWriter.jpegQuality == 0.85)
    }
}

// MARK: - 编码

@Suite("截图文件写入器编码")
@MainActor
struct ScreenshotEncodeTests {

    @Test("编码得到非空 JPEG 数据")
    func encodesJPEGData() throws {
        let image = makeImage(width: 40, height: 20)

        let data = try #require(ScreenshotFileWriter.encodeJPEG(image, quality: 0.85))

        #expect(data.isEmpty == false)
        // JPEG 文件头以 FFD8 开头
        #expect(data.first == 0xFF)
        #expect(data.dropFirst().first == 0xD8)
    }

    @Test("文件名带时间戳前缀与扩展名")
    func buildsFileName() {
        let name = ScreenshotFileWriter.makeFileName(ext: "jpg")

        #expect(name.hasPrefix("screenshot-"))
        #expect(name.hasSuffix(".jpg"))
        #expect(name.contains(":") == false)
    }

    @Test("写入目录后返回可读文件")
    func writesFileToDirectory() throws {
        let image = makeImage(width: 40, height: 20)
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ChatScreenshotTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let url = try ScreenshotFileWriter.write(image, to: directory)

        #expect(FileManager.default.fileExists(atPath: url.path))
        #expect(url.lastPathComponent.hasSuffix(".jpg"))
        #expect(try Data(contentsOf: url).isEmpty == false)
    }

    @Test("生成的附件是 JPEG 且带文件名")
    func buildsAttachment() throws {
        let image = makeImage(width: 40, height: 20)

        let attachment = try ScreenshotFileWriter.makeAttachment(image)

        #expect(attachment.mimeType == "image/jpeg")
        #expect(attachment.fileName?.hasSuffix(".jpg") == true)
        let data = try #require(Data(base64Encoded: attachment.base64Data))
        #expect(data.isEmpty == false)
    }

    @Test("超限图片先缩放再编码")
    func attachmentDownscalesLargeImage() throws {
        let image = makeImage(width: 4000, height: 2000)

        let attachment = try ScreenshotFileWriter.makeAttachment(image)
        let data = try #require(Data(base64Encoded: attachment.base64Data))

        #expect(data.isEmpty == false)
        #expect(attachment.mimeType == "image/jpeg")
    }
}

// MARK: - 裁剪边界

@Suite("截图裁剪边界")
struct ChatScreenshotCropBoundaryTests {

    @Test("抓取框无尺寸时返回 nil")
    func rejectsEmptyCaptureFrame() {
        let image = makeImage(width: 10, height: 10)

        #expect(
            ChatScreenshotState.crop(
                image: image,
                captureFrame: CGRect(x: 0, y: 0, width: 0, height: 100),
                selection: CGRect(x: 0, y: 0, width: 10, height: 10)
            ) == nil
        )
    }

    @Test("选区与图像无交集时返回 nil")
    func rejectsDisjointSelection() {
        let image = makeImage(width: 100, height: 100)

        #expect(
            ChatScreenshotState.crop(
                image: image,
                captureFrame: CGRect(x: 0, y: 0, width: 100, height: 100),
                selection: CGRect(x: 500, y: 500, width: 10, height: 10)
            ) == nil
        )
    }

    @Test("选区不足一个像素时按 1 像素裁剪")
    func cropsSubPixelSelectionToOnePixel() throws {
        let image = makeImage(width: 100, height: 100)

        let cropped = ChatScreenshotState.crop(
            image: image,
            captureFrame: CGRect(x: 0, y: 0, width: 100, height: 100),
            selection: CGRect(x: 10, y: 10, width: 0.2, height: 0.2)
        )

        // 实现先对选区取整再按「宽高 ≥ 1」判定，0.2pt 选区会落在 1×1 像素上。
        let result = try #require(cropped)
        #expect(result.width == 1)
        #expect(result.height == 1)
    }
}

// MARK: - 权限探测
//
// `ScreenCapturePermissionPrompter.ensurePermission()` 只是转发
// `CGPreflightScreenCaptureAccess()`，没有可测的分支逻辑；实测单次调用会让
// TCC 查询阻塞 40s 以上，且不保证在 CI 环境有屏幕录制授权，故不纳入单元测试。
