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

    func testRenderReturnsURLAndProducesExpectedSheetCount() async throws {
        // 1. Build a 6-page source PDF on disk.
        let sourceURL = try makeSourcePDF(pageCount: 6)
        defer { try? FileManager.default.removeItem(at: sourceURL) }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("booklet-renderer-test-\(UUID().uuidString).pdf")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        // 2. Render with the new explicit-result API.
        let renderer = BookletRenderer()
        let result = try await renderer.render(
            sourceURL: sourceURL,
            outputURL: outputURL,
            settings: BookletSettings() // defaults: bookletFold, A4, pad=true
        ) { _ in }

        // 3. Validate: success is the returned URL, not file existence.
        XCTAssertEqual(result, outputURL)
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
        let result = try await renderer.render(
            sourceURL: sourceURL,
            outputURL: outputURL,
            settings: BookletSettings()
        )

        XCTAssertEqual(result, outputURL)
        guard let outDoc = PDFDocument(url: outputURL) else {
            XCTFail("Output PDF cannot be opened")
            return
        }
        // 5 source pages → pad to 8 slots → 2 physical sheets /
        // 4 output PDF pages.
        XCTAssertEqual(outDoc.pageCount, 4)
    }

    func testCancelledRenderLeavesNoPartialOutput() async throws {
        let sourceURL = try makeSourcePDF(pageCount: 40)
        defer { try? FileManager.default.removeItem(at: sourceURL) }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("booklet-renderer-cancel-\(UUID().uuidString).pdf")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        let renderer = BookletRenderer()
        // Signal emitted once the renderer is mid-flight (past initial setup).
        let (started, startedContinuation) = AsyncStream.makeStream(of: Void.self)
        let worker = Task {
            try await renderer.render(
                sourceURL: sourceURL,
                outputURL: outputURL,
                settings: BookletSettings()
            ) { value in
                if value >= 0.09 {
                    startedContinuation.yield(())
                }
            }
        }

        for await _ in started { break }
        worker.cancel()
        startedContinuation.finish()

        do {
            _ = try await worker.value
            XCTFail("Expected cancellation to surface")
        } catch is CancellationError {
            // Expected: cancellation propagates to the consumer.
        }

        // A cancelled render must not leave a partial output behind.
        XCTAssertFalse(FileManager.default.fileExists(atPath: outputURL.path))
    }

    func testRenderWriteFailureThrows() async throws {
        let sourceURL = try makeSourcePDF(pageCount: 3)
        defer { try? FileManager.default.removeItem(at: sourceURL) }

        // Point the output at an existing directory so the atomic write fails.
        let bogusOutput = FileManager.default.temporaryDirectory
            .appendingPathComponent("booklet-renderer-dir-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: bogusOutput, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: bogusOutput) }

        let renderer = BookletRenderer()
        do {
            _ = try await renderer.render(
                sourceURL: sourceURL,
                outputURL: bogusOutput,
                settings: BookletSettings()
            )
            XCTFail("Expected write failure to throw")
        } catch {
            XCTAssertTrue(error is BookletRenderer.RenderError)
        }
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
