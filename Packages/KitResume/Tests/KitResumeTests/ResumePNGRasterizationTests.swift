import AppKit
import CoreGraphics
import Foundation
import PDFKit
import Testing
@testable import KitResume

/// PNG 栅格化 DPI 缩放回归（#487）。
///
/// 此前 `rasterize` 创建了像素级 bitmap context，但 `PDFPage.draw` 按
/// 1 pt = 1 px 绘制且未按 dpi/72 缩放 CTM，导致高 DPI 导出的位图只有
/// 左下角 dpi/72 大小的区域有内容，其余全是空白。
@Suite("Resume PNG 栅格化")
@MainActor
struct ResumePNGRasterizationTests {

    private struct TestSetupFailure: Error {}

    /// 构造一页整版黑色矩形的 A4 PDF（mediaBox = 595.5×842.25 pt，与生产一致）。
    private func makeFullPageBlackPDFPage() throws -> PDFPage {
        var mediaBox = CGRect(x: 0, y: 0, width: 595.5, height: 842.25)
        let pdfData = NSMutableData()
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw TestSetupFailure()
        }
        context.beginPDFPage(nil)
        context.setFillColor(CGColor(gray: 0, alpha: 1))
        context.fill(mediaBox)
        context.endPDFPage()
        context.closePDF()
        guard let page = PDFDocument(data: pdfData as Data)?.page(at: 0) else {
            throw TestSetupFailure()
        }
        return page
    }

    @Test("栅格化按目标 DPI 缩放内容，整页铺满而不是缩在角落（**回归 #487**）")
    func rasterizedPNGScalesContentByDpi() throws {
        let page = try makeFullPageBlackPDFPage()

        let data = try ResumeHTMLExporter.pngData(page: page, paper: .a4, dpi: 300)
        guard let rep = NSBitmapImageRep(data: data) else {
            throw TestSetupFailure()
        }
        #expect(rep.pixelsWide == 2481, "A4 @300dpi 应为 2481×3509 像素")
        #expect(rep.pixelsHigh == 3509)

        // 整版黑色内容缩放正确时，四角都应为黑；若未按 dpi/72 缩放，
        // 内容只占 CG 坐标系左下角（位图顶部两角仍是白底）。
        // colorAt 返回 calibrated RGB，直接取 whiteComponent 会抛异常，先转灰度。
        for (x, y) in [(1, 1), (rep.pixelsWide - 2, 1), (1, rep.pixelsHigh - 2), (rep.pixelsWide - 2, rep.pixelsHigh - 2)] {
            let white = rep.colorAt(x: x, y: y)?
                .usingColorSpace(.deviceGray)?.whiteComponent ?? 1
            #expect(white < 0.5, "位图 (\(x), \(y)) 应为内容色，实际 white=\(white)")
        }
    }
}
