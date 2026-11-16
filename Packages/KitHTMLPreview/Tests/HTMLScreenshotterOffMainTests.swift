import AppKit
import PDFKit
import Testing

@testable import KitHTMLPreview

/// 回归 issue #1263：PDF 解析与逐页栅格化必须能在后台线程执行，
/// 不依赖主 actor，避免每次 show_html 截图都阻塞 UI。
@Suite("HTMLScreenshotter off-main rasterization")
struct HTMLScreenshotterOffMainTests {

    private func makePDFData(width: CGFloat, height: CGFloat) throws -> Data {
        let document = PDFDocument()
        let page = PDFPage()
        page.setBounds(CGRect(x: 0, y: 0, width: width, height: height), for: .mediaBox)
        document.insert(page, at: 0)
        return try #require(document.dataRepresentation())
    }

    @Test("rasterizes a PDF off the main actor into a correctly sized bitmap")
    func rasterizesOffMain() async throws {
        let data = try makePDFData(width: 200, height: 300)
        let image = try await Task.detached(priority: .userInitiated) {
            try HTMLScreenshotter.rasterize(pdfData: data, limits: .standard)
        }.value
        #expect(image.width == 200)
        #expect(image.height == 300)
    }

    @Test("rejects an oversized PDF off the main actor before allocating a bitmap")
    func rejectsOversizedOffMain() async throws {
        let data = try makePDFData(width: 200, height: 300)
        await #expect(throws: HTMLScreenshotter.HTMLError.self) {
            _ = try await Task.detached(priority: .userInitiated) {
                try HTMLScreenshotter.rasterize(
                    pdfData: data,
                    limits: HTMLScreenshotLimits(maxPageCount: 64, maxPixels: 60_000, maxDimension: 250)
                )
            }.value
        }
    }
}