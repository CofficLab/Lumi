import AppKit
import Foundation
import PDFKit

/// 输出 PDF 缩略图的后台渲染与有界缓存（#1189）。
///
/// 原先每行在 `View.body` 里打开 PDF 并按整页 mediaBox 尺寸光栅化；转换进度
/// 每次发布都会让已完成的行重新打开并重新渲染。现在改为按 outputURL 异步渲染
/// 一次、只画出缩略图尺寸，并复用与输入图片相同的有界缓存。
enum PDFThumbnailLoader {

    /// 缩略图边长上限（像素）。行内显示 40pt，按 2x 屏幕取 80px。
    static let maxPixelSize = 80

    /// 在后台准备 PDF 首页缩略图：stat → 查缓存 → 渲染 → 写缓存。
    ///
    /// 调用方负责在写回 UI 前检查取消。
    nonisolated static func thumbnail(for url: URL) async -> NSImage? {
        let identity = ImageThumbnailLoader.fileIdentity(of: url)
        let key = ImageThumbnailKey(
            url: url,
            fileSize: identity.size,
            modificationDate: identity.modified
        )

        if let cached = await ImageThumbnailCache.shared.image(for: key) {
            return cached.image
        }
        guard !Task.isCancelled else { return nil }
        guard let image = makeThumbnail(at: url, maxPixelSize: maxPixelSize) else { return nil }
        await ImageThumbnailCache.shared.insert(image, for: key)
        return image
    }

    /// 把 PDF 首页渲染到缩略图尺寸的位图，避免整页光栅化的绘制与分配开销。
    ///
    /// 文档在本函数内创建并持有，只读不改，跨线程绘制安全。
    nonisolated static func makeThumbnail(at url: URL, maxPixelSize: Int) -> NSImage? {
        guard maxPixelSize > 0,
              let document = PDFDocument(url: url),
              let page = document.page(at: 0) else { return nil }

        let bounds = page.bounds(for: .mediaBox)
        guard bounds.width > 0, bounds.height > 0 else { return nil }

        let scale = min(1, CGFloat(maxPixelSize) / max(bounds.width, bounds.height))
        let width = max(1, Int(bounds.width * scale))
        let height = max(1, Int(bounds.height * scale))

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.scaleBy(x: scale, y: scale)
        page.draw(with: .mediaBox, to: context)

        guard let cgImage = context.makeImage() else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
    }
}