import AppKit
import Foundation
import ImageIO

/// 输入图片缩略图的后台加载与有界缓存（#1196）。
///
/// 原先每行在 `View.body` 里同步 `NSImage(contentsOf:)` 打开原图：非懒加载容器
/// 会一次性打开全部输入，且每次视图求值都重复打开。现在先渲染占位图，由行的
/// `.task` 在后台解码 + 降采样，按 URL + 文件身份缓存，行消失时取消。
enum ImageThumbnailLoader {

    /// 缩略图边长上限（像素）。行内显示 36pt，按 2x 屏幕取 72px。
    static let maxPixelSize = 72

    /// 在后台准备缩略图：stat → 查缓存 → 解码降采样 → 写缓存。
    ///
    /// `nonisolated async` 保证即使从主 actor 调用也在通用执行器上跑；
    /// 调用方负责在写回 UI 前检查取消。
    nonisolated static func thumbnail(for url: URL) async -> NSImage? {
        let identity = fileIdentity(of: url)
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

    /// 用 ImageIO 直接解码出降采样缩略图，避免把原图整张解码进内存。
    ///
    /// 纯同步且只读源文件，便于在后台线程调用与单元测试。
    nonisolated static func makeThumbnail(at url: URL, maxPixelSize: Int) -> NSImage? {
        guard maxPixelSize > 0,
              let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }

    /// 文件身份：大小 + 修改时间。原图被替换后缓存键随之变化，不会显示旧内容。
    nonisolated static func fileIdentity(of url: URL) -> (size: UInt64, modified: Date?) {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        return (
            (attributes?[.size] as? UInt64) ?? 0,
            attributes?[.modificationDate] as? Date
        )
    }
}

/// 缓存键：URL + 文件身份。
struct ImageThumbnailKey: Hashable, Sendable {
    let url: URL
    let fileSize: UInt64
    let modificationDate: Date?
}

/// `NSImage` 非 Sendable，装箱后跨 actor 传递；创建后只读，跨线程安全。
struct ImageThumbnailBox: @unchecked Sendable {
    let image: NSImage
}

/// 有界 LRU 缩略图缓存。输入数量无上界，缓存必须有上限。
actor ImageThumbnailCache {
    static let shared = ImageThumbnailCache()

    private let limit: Int
    private var images: [ImageThumbnailKey: ImageThumbnailBox] = [:]
    private var order: [ImageThumbnailKey] = []

    init(limit: Int = 64) {
        self.limit = max(1, limit)
    }

    var count: Int { images.count }

    func image(for key: ImageThumbnailKey) -> ImageThumbnailBox? {
        guard let box = images[key] else { return nil }
        touch(key)
        return box
    }

    func insert(_ image: NSImage, for key: ImageThumbnailKey) {
        if images[key] == nil { order.append(key) }
        images[key] = ImageThumbnailBox(image: image)
        touch(key)
        while order.count > limit {
            images.removeValue(forKey: order.removeFirst())
        }
    }

    func removeAll() {
        images.removeAll()
        order.removeAll()
    }

    private func touch(_ key: ImageThumbnailKey) {
        if let index = order.firstIndex(of: key) {
            order.remove(at: index)
        }
        order.append(key)
    }
}