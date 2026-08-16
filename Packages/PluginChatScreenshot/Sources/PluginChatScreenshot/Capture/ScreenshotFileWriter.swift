import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// 截图落盘工具：CGImage → 长边缩放 → JPEG → 写入插件数据目录。
///
/// 由旧版 `ScreenCaptureImageProcessor`（产出 `LumiImageAttachment`）改造而来：
/// 新版 `MessageSendingProviding` 无附件挂起池，截图统一保存为 JPEG 文件后，
/// 以文件路径文本插入输入框。
///
/// 设计：
/// - 长边最大 1920px（典型 4K/Retina 截图可缩到 ~3-5MB → JPEG 后 ~300-500KB）；
/// - JPEG quality 0.85（肉眼无损、显著小于 PNG）；
/// - 任何 CGImage 输入均可。
@MainActor
public enum ScreenshotFileWriter {
    public enum WriteError: Error {
        case encodeFailed
    }

    /// 长边最大像素；0 表示不缩放
    public static let maxDimension: CGFloat = 1920

    /// JPEG 质量（0..1）
    public static let jpegQuality: CGFloat = 0.85

    /// 缩放 + JPEG 编码后写入 `directory`，返回生成的图片文件 URL。
    public static func write(_ image: CGImage, to directory: URL) throws -> URL {
        let scaled = downscale(image, maxDimension: maxDimension)
        guard let jpegData = encodeJPEG(scaled, quality: jpegQuality) else {
            throw WriteError.encodeFailed
        }
        let url = directory.appendingPathComponent(makeFileName(ext: "jpg"))
        try jpegData.write(to: url)
        return url
    }

    // MARK: - 私有工具

    /// 等比缩放：长边 ≤ maxDimension
    public static func downscale(_ image: CGImage, maxDimension: CGFloat) -> CGImage {
        guard maxDimension > 0 else { return image }
        let w = CGFloat(image.width)
        let h = CGFloat(image.height)
        let longest = max(w, h)
        guard longest > maxDimension else { return image }

        let scale = maxDimension / longest
        let newW = Int((w * scale).rounded())
        let newH = Int((h * scale).rounded())
        guard newW > 0, newH > 0 else { return image }

        let colorSpace = image.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
            | CGBitmapInfo.byteOrder32Little.rawValue
        guard let ctx = CGContext(
            data: nil,
            width: newW,
            height: newH,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return image
        }
        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: newW, height: newH))
        return ctx.makeImage() ?? image
    }

    /// JPEG 编码到 Data
    public static func encodeJPEG(_ image: CGImage, quality: CGFloat) -> Data? {
        let mutableData = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(
            mutableData,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            return nil
        }
        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality
        ]
        CGImageDestinationAddImage(dest, image, options as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return mutableData as Data
    }

    public static func makeFileName(ext: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withYear, .withMonth, .withDay, .withTime]
        let stamp = formatter.string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        return "screenshot-\(stamp).\(ext)"
    }
}
