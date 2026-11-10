import AppKit
import Foundation
import PDFKit
import PluginBookletMaker

/// 测试宿主对 `BookletMakerTestHooks` 的驱动。
///
/// 合并队列在真实使用中由用户经 `NSOpenPanel` 填充，而该面板在 App 的
/// 辅助功能树之外运行，XCUITest 无法驱动。因此这里改用插件提供的测试接缝
/// 直接注入文件：注入走的是 `loadMergePDFs(_:appending:)`，与用户选择文件
/// 同一条路径，同样做可读性检查、页数统计与去重。
@MainActor
enum MergeQueueFixture {

    /// 生成 `count` 份页数依次为 `1...count` 的临时 PDF。
    ///
    /// 页数刻意各不相同：只有各文件页数可区分，测试才能断言「顺序真的变了」，
    /// 而不是仅凭文件名猜测。
    static func makePDFs(count: Int) throws -> [URL] {
        var urls: [URL] = []
        for pageCount in 1 ... count {
            urls.append(try makePDF(pageCount: pageCount))
        }
        return urls
    }

    /// 生成一份指定页数的 PDF。
    ///
    /// 用 PDFKit 直接排版而不是手写 PDF 字节：插件自身也用 PDFKit 读这些文件，
    /// 两边对「合法 PDF」的理解一致，避免夹具产出的文件插件读不出来。
    private static func makePDF(pageCount: Int) throws -> URL {
        let document = PDFDocument()
        for page in 1 ... max(pageCount, 1) {
            let image = renderPageLabel(page)
            guard let pdfPage = PDFPage(image: image) else {
                throw CocoaError(.fileWriteUnknown)
            }
            document.insert(pdfPage, at: document.pageCount)
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("merge-fixture-\(UUID().uuidString).pdf")
        guard document.write(to: url) else {
            throw CocoaError(.fileWriteUnknown)
        }
        return url
    }

    /// 把页序号画成一张图，作为该页的内容。
    private static func renderPageLabel(_ page: Int) -> NSImage {
        let size = NSSize(width: 300, height: 400)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.white.setFill()
        NSRect(origin: .zero, size: size).fill()
        let text = "Merge fixture page \(page)" as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 24),
            .foregroundColor: NSColor.black,
        ]
        text.draw(
            in: NSRect(x: 20, y: size.height / 2, width: size.width - 40, height: 60),
            withAttributes: attributes
        )
        image.unlockFocus()
        return image
    }
}
