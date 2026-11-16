import AppKit
import Foundation
import Testing
@testable import ImageToPDFPlugin

/// 回归 #1196：输入行不得在 `View.body` 里同步打开原图。
/// 缩略图改为后台解码 + 降采样，按 URL + 文件身份有界缓存。
@Suite("Image-to-PDF input thumbnails off-main")
struct ImageThumbnailLoaderTests {

    @Test("缩略图解码在后台线程执行且被降采样")
    func makeThumbnailRunsOffMain() async throws {
        let url = try makePNGFile(width: 400, height: 300)
        defer { try? FileManager.default.removeItem(at: url) }

        let flag = ThreadFlag()
        let size = await Task.detached(priority: .userInitiated) {
            runMakeThumbnailOffMain(url: url, flag: flag)
        }.value

        #expect(flag.value == false, "缩略图解码不应发生在主线程")
        let resolved = try #require(size)
        #expect(max(resolved.width, resolved.height) <= CGFloat(ImageThumbnailLoader.maxPixelSize))
    }

    @Test("缺失或非图片文件返回 nil")
    func unreadableFileReturnsNil() async throws {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).png")
        #expect(ImageThumbnailLoader.makeThumbnail(at: missing, maxPixelSize: 72) == nil)
        #expect(await ImageThumbnailLoader.thumbnail(for: missing) == nil)

        let notAnImage = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: notAnImage) }
        try Data("not an image".utf8).write(to: notAnImage)
        #expect(ImageThumbnailLoader.makeThumbnail(at: notAnImage, maxPixelSize: 72) == nil)
    }

    @Test("同一文件重复请求命中缓存，不重复解码")
    func repeatedRequestHitsCache() async throws {
        let url = try makePNGFile(width: 120, height: 80)
        defer { try? FileManager.default.removeItem(at: url) }

        let first = try #require(await ImageThumbnailLoader.thumbnail(for: url))
        let second = try #require(await ImageThumbnailLoader.thumbnail(for: url))

        #expect(first === second)
    }

    @Test("原图被替换后缓存键失效，返回新内容")
    func fileIdentityInvalidatesCache() async throws {
        // 两张图都小于缩略图边长上限，尺寸不会被钳制，便于区分新旧内容。
        let url = try makePNGFile(width: 20, height: 10)
        defer { try? FileManager.default.removeItem(at: url) }

        let first = try #require(await ImageThumbnailLoader.thumbnail(for: url))
        try makePNGData(width: 40, height: 20).write(to: url, options: .atomic)
        let second = try #require(await ImageThumbnailLoader.thumbnail(for: url))

        #expect(first.size.width == 20)
        #expect(second.size.width == 40)
    }

    @Test("缓存有上限并按 LRU 淘汰")
    func cacheIsBounded() async throws {
        let cache = ImageThumbnailCache(limit: 2)
        let image = NSImage(size: NSSize(width: 4, height: 4))
        let keys = (0..<3).map { index in
            ImageThumbnailKey(
                url: URL(fileURLWithPath: "/tmp/thumbnail-\(index).png"),
                fileSize: UInt64(index),
                modificationDate: nil
            )
        }

        await cache.insert(image, for: keys[0])
        await cache.insert(image, for: keys[1])
        // 访问 keys[0] 使其成为最近使用，应淘汰 keys[1]。
        _ = await cache.image(for: keys[0])
        await cache.insert(image, for: keys[2])

        #expect(await cache.count == 2)
        #expect(await cache.image(for: keys[1]) == nil)
        #expect(await cache.image(for: keys[0]) != nil)
        #expect(await cache.image(for: keys[2]) != nil)
    }
}

// MARK: - Helpers

/// 同步函数：在后台线程记录是否主线程并解码缩略图。
/// `Thread.isMainThread` 不能直接在 async 闭包里引用，故包进同步函数。
private func runMakeThumbnailOffMain(url: URL, flag: ThreadFlag) -> NSSize? {
    flag.value = Thread.isMainThread
    return ImageThumbnailLoader.makeThumbnail(
        at: url,
        maxPixelSize: ImageThumbnailLoader.maxPixelSize
    )?.size
}

private func makePNGFile(width: Int, height: Int) throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("\(UUID().uuidString).png")
    try makePNGData(width: width, height: height).write(to: url)
    return url
}

private func makePNGData(width: Int, height: Int) throws -> Data {
    let context = try #require(CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ))
    context.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    let image = try #require(context.makeImage())
    let representation = NSBitmapImageRep(cgImage: image)
    return try #require(representation.representation(using: .png, properties: [:]))
}

private final class ThreadFlag: @unchecked Sendable {
    var value = false
}