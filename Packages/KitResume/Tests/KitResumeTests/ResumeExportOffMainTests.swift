import AppKit
import Foundation
import PDFKit
import Testing

@testable import KitResume

/// 简历 PNG 栅格化与编码必须在后台线程执行（Issue #1179）。
@Suite("Resume PNG export off-main")
@MainActor
struct ResumeExportOffMainTests {

    @Test("pngData 在后台线程栅格化并编码出目标尺寸 PNG")
    func pngDataRunsOffMain() async throws {
        let document = try #require(Self.makePDFDocument())
        let page = try #require(document.page(at: 0))
        let box = PageBox(page: page)
        let flag = ThreadFlag()
        let dpi = ResumeExportResolution.screen.rawValue

        let data = try await Task.detached(priority: .userInitiated) {
            try Self.runPNGDataOffMain(flag: flag, page: box.page, dpi: dpi)
        }.value

        #expect(flag.value == false, "PNG 栅格化与编码必须在非主线程执行")
        let rep = try #require(NSBitmapImageRep(data: data))
        let expected = ResumePaperSpec.preset(for: .a4).pixelSize(dpi: dpi)
        #expect(abs(rep.pixelsWide - Int(expected.width)) <= 1)
        #expect(abs(rep.pixelsHigh - Int(expected.height)) <= 1)
    }

    /// 同步辅助函数：记录当前线程并调用生产栅格化逻辑。
    ///
    /// `Thread.isMainThread` 在 async 上下文不可用，必须放在同步函数里。
    nonisolated private static func runPNGDataOffMain(flag: ThreadFlag, page: PDFPage, dpi: Int) throws -> Data {
        flag.value = Thread.isMainThread
        return try ResumeHTMLExporter.pngData(page: page, paper: .a4, dpi: dpi)
    }

    private static func makePDFDocument() -> PDFDocument? {
        let image = NSImage(size: NSSize(width: 100, height: 100))
        image.lockFocus()
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: 100, height: 100).fill()
        image.unlockFocus()
        guard let page = PDFPage(image: image) else { return nil }
        let document = PDFDocument()
        document.insert(page, at: 0)
        return document
    }
}

private struct PageBox: @unchecked Sendable {
    let page: PDFPage
}

private final class ThreadFlag: @unchecked Sendable {
    var value = false
}