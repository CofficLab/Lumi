import CoreGraphics
import Foundation
import ImageIO
import LumiKernel
import UniformTypeIdentifiers

/// 截图编码工具:CGImage → 长边缩放 → JPEG → base64 → LumiImageAttachment
///
/// 设计:
/// - 长边最大 1920px(典型 4K/Retina 截图可缩到 ~3-5MB → JPEG 后 ~300-500KB → base64 ~400-700KB)
/// - JPEG quality 0.85(肉眼无损、显著小于 PNG)
/// - 任何 CGImage 输入均可(JPEG/PNG/raw 都行,因为通过 `CGImageSource` 解码)
@MainActor
public enum ScreenCaptureImageProcessor {

    /// 长边最大像素;0 表示不缩放
    public static let maxDimension: CGFloat = 1920

    /// JPEG 质量(0..1)
    public static let jpegQuality: CGFloat = 0.85

    /// 从任意 Data 输入构造一个压缩到目标大小的 JPEG `LumiImageAttachment`
    ///
    /// - Parameter sourceData: 截图原图(任何常见编码:PNG/JPEG/raw)
    /// - Returns: JPEG 编码、长边 1920、base64 化的 attachment
    public static func makeAttachment(from sourceData: Data) -> LumiImageAttachment {
        // 1. 解码为 CGImage
        let original: CGImage
        if let src = CGImageSourceCreateWithData(sourceData as CFData, nil),
           let img = CGImageSourceCreateImageAtIndex(src, 0, nil) {
            original = img
        } else {
            // fallback:直接 base64 编码原数据,假定已是 JPEG
            return LumiImageAttachment(
                mimeType: "image/jpeg",
                base64Data: sourceData.base64EncodedString(),
                fileName: makeFileName(ext: "jpg")
            )
        }

        // 2. 长边缩放
        let scaled = downscale(original, maxDimension: maxDimension)

        // 3. JPEG 编码
        let jpegData = encodeJPEG(scaled, quality: jpegQuality) ?? sourceData

        return LumiImageAttachment(
            mimeType: "image/jpeg",
            base64Data: jpegData.base64EncodedString(),
            fileName: makeFileName(ext: "jpg")
        )
    }

    /// 从 CGImage 直接构造(用于已 crop 的小图)
    public static func makeAttachment(from cgImage: CGImage) -> LumiImageAttachment {
        let scaled = downscale(cgImage, maxDimension: maxDimension)
        let jpegData = encodeJPEG(scaled, quality: jpegQuality) ?? Data()
        return LumiImageAttachment(
            mimeType: "image/jpeg",
            base64Data: jpegData.base64EncodedString(),
            fileName: makeFileName(ext: "jpg")
        )
    }

    // MARK: - 私有工具

    /// 等比缩放:长边 ≤ maxDimension
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