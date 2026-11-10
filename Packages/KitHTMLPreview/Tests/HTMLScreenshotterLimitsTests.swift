import Testing

@testable import KitHTMLPreview

/// 回归覆盖 issue #1055：CSS 文档高度不能绕过快照的页数与像素上限。
@Suite("HTMLScreenshotter limits")
struct HTMLScreenshotterLimitsTests {

    @Test("ordinary pages fit within the standard limits")
    func ordinaryPagesFit() {
        let geometry = HTMLScreenshotGeometry(pageCount: 3, width: 800, height: 2_000)

        #expect(!geometry.isEmpty)
        #expect(!geometry.exceeds(.standard))
    }

    @Test("too many PDF pages are rejected")
    func pageCountLimitRejectsEndlessDocument() {
        let geometry = HTMLScreenshotGeometry(
            pageCount: HTMLScreenshotLimits.standard.maxPageCount + 1,
            width: 200,
            height: 5_000
        )

        #expect(geometry.exceeds(.standard))
    }

    @Test("a single page taller than the dimension limit is rejected")
    func tallPageIsRejected() {
        let geometry = HTMLScreenshotGeometry(
            pageCount: 1,
            width: 800,
            height: HTMLScreenshotLimits.standard.maxDimension + 1
        )

        #expect(geometry.exceeds(.standard))
    }

    @Test("total pixel area is bounded independently of each side")
    func pixelBudgetRejectsLargeArea() {
        let geometry = HTMLScreenshotGeometry(pageCount: 4, width: 4_000, height: 8_000)

        #expect(geometry.width <= HTMLScreenshotLimits.standard.maxDimension)
        #expect(geometry.height <= HTMLScreenshotLimits.standard.maxDimension)
        #expect(geometry.exceeds(.standard))
    }

    @Test("empty geometry is detected before allocation")
    func emptyGeometryIsDetected() {
        #expect(HTMLScreenshotGeometry(pageCount: 0, width: 800, height: 600).isEmpty)
        #expect(HTMLScreenshotGeometry(pageCount: 2, width: 0, height: 600).isEmpty)
        #expect(HTMLScreenshotGeometry(pageCount: 2, width: 800, height: 0).isEmpty)
    }

    @Test("oversize error explains the actual size")
    func oversizeErrorIsDescriptive() {
        let error = HTMLScreenshotter.HTMLError.snapshotTooLarge(
            pageCount: 500,
            width: 200,
            height: 100_000
        )
        let description = error.errorDescription ?? ""

        #expect(description.contains("too large"))
        #expect(description.contains("500 pages"))
        #expect(description.contains("200x100000"))
    }
}
