import AppKit
import Foundation
import PDFKit
import Testing
@testable import ImageToPDFPlugin

/// 回归 #1189：输出行不得在 `View.body` 里打开并整页光栅化 PDF。
/// 缩略图改为后台渲染到缩略图尺寸，按 outputURL + 文件身份有界缓存。
@Suite("Image-to-PDF output thumbnails off-main")
struct PDFThumbnailLoaderTests {

    @Test("PDF 渲染在后台线程执行且只画出缩略图尺寸")
    func makeThumbnailRunsOffMain() async throws {
        let url = try makePDFFile(width: 600, height: 400)
        defer { try? FileManager.default.removeItem(at: url) }

        let flag = ThreadFlag()
        let size = await Task.detached(priority: .userInitiated) {
            runMakePDFThumbnailOffMain(url: url, flag: flag)
        }.value

        #expect(flag.value == false, "PDF 打开与光栅化不应发生在主线程")
        let resolved = try #require(size)
        #expect(max(resolved.width, resolved.height) <= CGFloat(PDFThumbnailLoader.maxPixelSize))
    }

    @Test("缺失或非 PDF 文件返回 nil")
    func unreadableFileReturnsNil() async throws {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).pdf")
        #expect(PDFThumbnailLoader.makeThumbnail(at: missing, maxPixelSize: 80) == nil)
        #expect(await PDFThumbnailLoader.thumbnail(for: missing) == nil)

        let notAPDF = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).pdf")
        defer { try? FileManager.default.removeItem(at: notAPDF) }
        try Data("not a pdf".utf8).write(to: notAPDF)
        #expect(PDFThumbnailLoader.makeThumbnail(at: notAPDF, maxPixelSize: 80) == nil)
    }

    @Test("同一 outputURL 重复请求命中缓存，不重复渲染")
    func repeatedRequestHitsCache() async throws {
        let url = try makePDFFile(width: 200, height: 150)
        defer { try? FileManager.default.removeItem(at: url) }

        let first = try #require(await PDFThumbnailLoader.thumbnail(for: url))
        let second = try #require(await PDFThumbnailLoader.thumbnail(for: url))

        #expect(first === second)
    }

    @Test("PDF 被替换后缓存键失效，返回新内容")
    func fileIdentityInvalidatesCache() async throws {
        // 两页都小于缩略图边长上限，尺寸不会被钳制，便于区分新旧内容。
        let url = try makePDFFile(width: 20, height: 10)
        defer { try? FileManager.default.removeItem(at: url) }

        let first = try #require(await PDFThumbnailLoader.thumbnail(for: url))
        let replacement = try makePDFFile(width: 40, height: 20)
        defer { try? FileManager.default.removeItem(at: replacement) }
        try Data(contentsOf: replacement).write(to: url, options: .atomic)
        let second = try #require(await PDFThumbnailLoader.thumbnail(for: url))

        #expect(first.size.width == 20)
        #expect(second.size.width == 40)
    }
}

// MARK: - Helpers

/// 同步函数：在后台线程记录是否主线程并渲染 PDF 缩略图。
/// `Thread.isMainThread` 不能直接在 async 闭包里引用，故包进同步函数。
private func runMakePDFThumbnailOffMain(url: URL, flag: ThreadFlag) -> NSSize? {
    flag.value = Thread.isMainThread
    return PDFThumbnailLoader.makeThumbnail(
        at: url,
        maxPixelSize: PDFThumbnailLoader.maxPixelSize
    )?.size
}

private func makePDFFile(width: CGFloat, height: CGFloat) throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("\(UUID().uuidString).pdf")
    let data = NSMutableData()
    let consumer = try #require(CGDataConsumer(data: data))
    var mediaBox = CGRect(x: 0, y: 0, width: width, height: height)
    let context = try #require(CGContext(consumer: consumer, mediaBox: &mediaBox, nil))

    context.beginPDFPage(nil)
    context.setFillColor(CGColor(red: 0.8, green: 0.2, blue: 0.2, alpha: 1))
    context.fill(mediaBox)
    context.endPDFPage()
    context.closePDF()

    try data.write(to: url)
    return url
}

private final class ThreadFlag: @unchecked Sendable {
    var value = false
}