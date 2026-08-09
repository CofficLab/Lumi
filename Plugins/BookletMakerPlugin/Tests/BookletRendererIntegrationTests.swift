import CoreGraphics
import Foundation
import PDFKit
import XCTest
@testable import BookletMakerPlugin

// MARK: - Renderer Integration Test

/// Builds a tiny source PDF entirely in memory, runs the renderer
/// end-to-end, then re-opens the produced PDF and verifies the number
/// of output pages.
final class BookletRendererIntegrationTests: XCTestCase {

    func testRenderProducesExpectedSheetCount() async throws {
        // 1. Build a 6-page source PDF on disk.
        let sourceURL = try makeSourcePDF(pageCount: 6)
        defer { try? FileManager.default.removeItem(at: sourceURL) }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("booklet-renderer-test-\(UUID().uuidString).pdf")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        // 2. Render.
        let renderer = BookletRenderer()
        let stream = renderer.render(
            sourceURL: sourceURL,
            outputURL: outputURL,
            settings: BookletSettings() // defaults: bookletFold, A4, pad=true
        )
        for await _ in stream { /* drain progress */ }

        // 3. Validate.
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
        guard let outDoc = PDFDocument(url: outputURL) else {
            XCTFail("Output PDF cannot be opened")
            return
        }
        // 6 source pages → pad to 8 slots → 2 physical sheets /
        // 4 output PDF pages (front/back for each sheet).
        XCTAssertEqual(outDoc.pageCount, 4)

        // Each output sheet is a landscape A4 page.
        let outputBounds = try XCTUnwrap(outDoc.page(at: 0)?.bounds(for: .mediaBox))
        XCTAssertGreaterThan(outputBounds.width, outputBounds.height)
    }

    func testRenderPadsOddInput() async throws {
        let sourceURL = try makeSourcePDF(pageCount: 5)
        defer { try? FileManager.default.removeItem(at: sourceURL) }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("booklet-renderer-test-\(UUID().uuidString).pdf")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        let renderer = BookletRenderer()
        let stream = renderer.render(
            sourceURL: sourceURL,
            outputURL: outputURL,
            settings: BookletSettings()
        )
        for await _ in stream {}

        guard let outDoc = PDFDocument(url: outputURL) else {
            XCTFail("Output PDF cannot be opened")
            return
        }
        // 5 source pages → pad to 8 slots → 2 physical sheets /
        // 4 output PDF pages.
        XCTAssertEqual(outDoc.pageCount, 4)
    }

    // MARK: - Helpers

    /// Generate a tiny `pageCount`-page A4 PDF on disk. Each page is
    /// filled with a solid colour so that we can also visually verify
    /// the output if we ever want to.
    private func makeSourcePDF(pageCount: Int) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("booklet-source-\(UUID().uuidString).pdf")
        let data = NSMutableData()
        var mediaBox = CGRect(x: 0, y: 0, width: 595, height: 842) // A4 in points
        guard let consumer = CGDataConsumer(data: data),
              let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw NSError(domain: "BookletRendererTest", code: 1)
        }
        for i in 0..<pageCount {
            ctx.beginPDFPage(nil)
            ctx.setFillColor(red: Double(i) / Double(max(pageCount, 1)),
                             green: 0.5,
                             blue: 0.7,
                             alpha: 1.0)
            ctx.fill(mediaBox)
            ctx.endPDFPage()
        }
        ctx.closePDF()
        try (data as Data).write(to: url, options: .atomic)
        return url
    }
}
