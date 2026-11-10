import CoreGraphics
import Foundation
import PDFKit
import XCTest
@testable import PluginBookletMaker

/// Tests for `PDFMerger`, the service behind the "Merge PDF" tool.
///
/// Page order is asserted through per-source page sizes: every fixture writes
/// a distinctive page size, so a merge that reorders or interleaves sources
/// fails instead of silently producing a plausible-looking document.
final class PDFMergerTests: XCTestCase {

    // MARK: - Page order

    func testMergesSourcesInTheGivenOrder() async throws {
        let portrait = try makeSourcePDF(pageCount: 3, pageSize: a4)
        let landscape = try makeSourcePDF(pageCount: 2, pageSize: a5)
        let outputURL = makeTemporaryURL(named: "merged")
        defer {
            try? FileManager.default.removeItem(at: portrait)
            try? FileManager.default.removeItem(at: landscape)
            try? FileManager.default.removeItem(at: outputURL)
        }

        let result = try await PDFMerger().merge(
            sourceURLs: [portrait, landscape],
            outputURL: outputURL
        )

        XCTAssertEqual(result, outputURL)
        let output = try XCTUnwrap(PDFDocument(url: outputURL))
        XCTAssertEqual(output.pageCount, 5)
        XCTAssertEqual(
            try pageSizes(of: output),
            [a4, a4, a4, a5, a5],
            "Pages must follow the source order, portrait first"
        )
    }

    func testReversingSourceOrderReversesOutputPages() async throws {
        let portrait = try makeSourcePDF(pageCount: 2, pageSize: a4)
        let landscape = try makeSourcePDF(pageCount: 3, pageSize: a5)
        let outputURL = makeTemporaryURL(named: "merged-reversed")
        defer {
            try? FileManager.default.removeItem(at: portrait)
            try? FileManager.default.removeItem(at: landscape)
            try? FileManager.default.removeItem(at: outputURL)
        }

        try await PDFMerger().merge(
            sourceURLs: [landscape, portrait],
            outputURL: outputURL
        )

        let output = try XCTUnwrap(PDFDocument(url: outputURL))
        XCTAssertEqual(output.pageCount, 5)
        XCTAssertEqual(try pageSizes(of: output), [a5, a5, a5, a4, a4])
    }

    func testMergedDocumentKeepsPageContentReadable() async throws {
        let first = try makeSourcePDF(pageCount: 2, pageSize: a4)
        let second = try makeSourcePDF(pageCount: 1, pageSize: a4)
        let outputURL = makeTemporaryURL(named: "merged-readable")
        defer {
            try? FileManager.default.removeItem(at: first)
            try? FileManager.default.removeItem(at: second)
            try? FileManager.default.removeItem(at: outputURL)
        }

        try await PDFMerger().merge(sourceURLs: [first, second], outputURL: outputURL)

        let output = try XCTUnwrap(PDFDocument(url: outputURL))
        XCTAssertFalse(output.isLocked)
        XCTAssertFalse(output.isEncrypted)
        // Merging must not rasterise: every page still has a real CGPDF backing.
        for index in 0 ..< output.pageCount {
            let page = try XCTUnwrap(output.page(at: index))
            XCTAssertNotNil(page.pageRef, "Page \(index) lost its backing PDF")
        }
    }

    // MARK: - Source validation

    func testRejectsFewerThanTwoSources() async throws {
        let single = try makeSourcePDF(pageCount: 1, pageSize: a4)
        let outputURL = makeTemporaryURL(named: "merged-too-few")
        defer {
            try? FileManager.default.removeItem(at: single)
            try? FileManager.default.removeItem(at: outputURL)
        }

        for sources in [[], [single]] {
            do {
                _ = try await PDFMerger().merge(sourceURLs: sources, outputURL: outputURL)
                XCTFail("Expected merge of \(sources.count) source(s) to be rejected")
            } catch let error as PDFMerger.MergeError {
                guard case .tooFewSources = error else {
                    return XCTFail("Expected tooFewSources, got \(error)")
                }
            }
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: outputURL.path))
    }

    func testRejectsMissingSource() async throws {
        let valid = try makeSourcePDF(pageCount: 2, pageSize: a4)
        let missing = makeTemporaryURL(named: "does-not-exist")
        let outputURL = makeTemporaryURL(named: "merged-missing")
        defer {
            try? FileManager.default.removeItem(at: valid)
            try? FileManager.default.removeItem(at: outputURL)
        }

        do {
            _ = try await PDFMerger().merge(
                sourceURLs: [valid, missing],
                outputURL: outputURL
            )
            XCTFail("Expected a missing source to be rejected")
        } catch let error as PDFMerger.MergeError {
            guard case .sourceUnreadable(let url) = error else {
                return XCTFail("Expected sourceUnreadable, got \(error)")
            }
            XCTAssertEqual(url.standardizedFileURL, missing.standardizedFileURL)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: outputURL.path))
    }

    func testRejectsSourceThatIsNotAValidPDF() async throws {
        let valid = try makeSourcePDF(pageCount: 1, pageSize: a4)
        let corrupt = makeTemporaryURL(named: "corrupt")
        try Data("this is not a pdf".utf8).write(to: corrupt, options: .atomic)
        let outputURL = makeTemporaryURL(named: "merged-corrupt")
        defer {
            try? FileManager.default.removeItem(at: valid)
            try? FileManager.default.removeItem(at: corrupt)
            try? FileManager.default.removeItem(at: outputURL)
        }

        do {
            _ = try await PDFMerger().merge(
                sourceURLs: [valid, corrupt],
                outputURL: outputURL
            )
            XCTFail("Expected a corrupt source to be rejected")
        } catch is PDFMerger.MergeError {
            // Expected.
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: outputURL.path))
    }

    // MARK: - Output handling

    func testReportsWriteFailureWhenOutputDirectoryIsMissing() async throws {
        let first = try makeSourcePDF(pageCount: 1, pageSize: a4)
        let second = try makeSourcePDF(pageCount: 1, pageSize: a4)
        let outputURL = makeTemporaryURL(named: "nested").appendingPathComponent("out.pdf")
        defer {
            try? FileManager.default.removeItem(at: first)
            try? FileManager.default.removeItem(at: second)
        }

        do {
            _ = try await PDFMerger().merge(
                sourceURLs: [first, second],
                outputURL: outputURL
            )
            XCTFail("Expected writing into a missing directory to fail")
        } catch let error as PDFMerger.MergeError {
            guard case .writeFailed = error else {
                return XCTFail("Expected writeFailed, got \(error)")
            }
        }
    }

    func testOverwritesAnExistingOutputFile() async throws {
        let first = try makeSourcePDF(pageCount: 1, pageSize: a4)
        let second = try makeSourcePDF(pageCount: 3, pageSize: a5)
        let outputURL = makeTemporaryURL(named: "merged-overwrite")
        defer {
            try? FileManager.default.removeItem(at: first)
            try? FileManager.default.removeItem(at: second)
            try? FileManager.default.removeItem(at: outputURL)
        }
        try Data("stale contents".utf8).write(to: outputURL, options: .atomic)

        try await PDFMerger().merge(sourceURLs: [first, second], outputURL: outputURL)

        let output = try XCTUnwrap(PDFDocument(url: outputURL))
        XCTAssertEqual(output.pageCount, 4, "Stale output must be fully replaced")
    }

    // MARK: - Progress reporting

    func testProgressRisesMonotonicallyAndFinishesAtOne() async throws {
        let sources = try (0 ..< 4).map { index in
            try makeSourcePDF(pageCount: index + 1, pageSize: a4)
        }
        let outputURL = makeTemporaryURL(named: "merged-progress")
        defer {
            sources.forEach { try? FileManager.default.removeItem(at: $0) }
            try? FileManager.default.removeItem(at: outputURL)
        }

        let recorder = ProgressRecorder()
        try await PDFMerger().merge(
            sourceURLs: sources,
            outputURL: outputURL,
            progress: { recorder.record($0) }
        )

        let values = recorder.values
        XCTAssertFalse(values.isEmpty)
        let final = try XCTUnwrap(values.last)
        XCTAssertEqual(final, 1, accuracy: 0.0001)
        for (previous, next) in zip(values, values.dropFirst()) {
            XCTAssertLessThanOrEqual(previous, next, "Progress must never go backwards: \(values)")
        }
        // One callback per source while copying pages, capped at 0.9 before
        // serialisation, then the terminal 1.
        XCTAssertEqual(values.count, sources.count + 1)
    }

    // MARK: - Cancellation

    func testCancellingMidMergeThrowsAndWritesNoOutput() async throws {
        let first = try makeSourcePDF(pageCount: 200, pageSize: a4)
        let second = try makeSourcePDF(pageCount: 200, pageSize: a5)
        let outputURL = makeTemporaryURL(named: "merged-cancel")
        defer {
            try? FileManager.default.removeItem(at: first)
            try? FileManager.default.removeItem(at: second)
            try? FileManager.default.removeItem(at: outputURL)
        }

        // The merger reports progress once per source, so the first callback
        // means source one has been fully consumed and source two is next.
        let firstProgress = AsyncStream<Void>.makeStream()
        let worker = Task {
            try await PDFMerger().merge(
                sourceURLs: [first, second],
                outputURL: outputURL,
                progress: { value in
                    if value > 0 {
                        firstProgress.continuation.yield(())
                    }
                }
            )
        }

        for await _ in firstProgress.stream { break }
        worker.cancel()

        do {
            _ = try await worker.value
            XCTFail("Expected cancellation to surface")
        } catch is CancellationError {
            // Expected.
        }
        firstProgress.continuation.finish()

        XCTAssertFalse(
            FileManager.default.fileExists(atPath: outputURL.path),
            "A cancelled merge must not leave an output file behind"
        )
    }

    func testCancellationBeforeStartIsHonoured() async throws {
        let first = try makeSourcePDF(pageCount: 1, pageSize: a4)
        let second = try makeSourcePDF(pageCount: 1, pageSize: a4)
        let outputURL = makeTemporaryURL(named: "merged-pre-cancel")
        defer {
            try? FileManager.default.removeItem(at: first)
            try? FileManager.default.removeItem(at: second)
            try? FileManager.default.removeItem(at: outputURL)
        }

        let worker = Task {
            try await PDFMerger().merge(
                sourceURLs: [first, second],
                outputURL: outputURL
            )
        }
        worker.cancel()

        do {
            _ = try await worker.value
            XCTFail("Expected cancellation to surface")
        } catch {
            XCTAssertTrue(
                error is CancellationError || error is PDFMerger.MergeError,
                "Unexpected error: \(error)"
            )
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: outputURL.path))
    }

    // MARK: - Error messages

    func testMergeErrorsCarryLocalizedDescriptions() {
        let url = URL(fileURLWithPath: "/tmp/example.pdf")
        XCTAssertFalse(PDFMerger.MergeError.tooFewSources.errorDescription?.isEmpty ?? true)
        XCTAssertFalse(PDFMerger.MergeError.sourceUnreadable(url).errorDescription?.isEmpty ?? true)
        XCTAssertFalse(PDFMerger.MergeError.outputContextFailed(url).errorDescription?.isEmpty ?? true)
        XCTAssertFalse(PDFMerger.MergeError.writeFailed(url).errorDescription?.isEmpty ?? true)
    }

    // MARK: - Helpers

    private var a4: CGSize { CGSize(width: 595, height: 842) }
    private var a5: CGSize { CGSize(width: 420, height: 595) }

    /// Collects progress values from the merger's background queue.
    private final class ProgressRecorder: @unchecked Sendable {
        private let lock = NSLock()
        private var storage: [Double] = []

        var values: [Double] {
            lock.lock()
            defer { lock.unlock() }
            return storage
        }

        func record(_ value: Double) {
            lock.lock()
            storage.append(value)
            lock.unlock()
        }
    }

    private func pageSizes(of document: PDFDocument) throws -> [CGSize] {
        try (0 ..< document.pageCount).map { index in
            let page = try XCTUnwrap(document.page(at: index), "Missing page \(index)")
            return page.bounds(for: .mediaBox).size
        }
    }

    private func makeTemporaryURL(named name: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("merger-\(name)-\(UUID().uuidString).pdf")
    }

    private func makeSourcePDF(pageCount: Int, pageSize: CGSize) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("merge-source-\(UUID().uuidString).pdf")
        let data = NSMutableData()
        var mediaBox = CGRect(origin: .zero, size: pageSize)
        guard let consumer = CGDataConsumer(data: data),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw NSError(domain: "PDFMergerTests", code: 1)
        }
        for index in 0 ..< pageCount {
            context.beginPDFPage(nil)
            context.setFillColor(
                red: Double(index + 1) / Double(pageCount + 1),
                green: 0.4,
                blue: 0.7,
                alpha: 1
            )
            context.fill(mediaBox)
            context.endPDFPage()
        }
        context.closePDF()
        try (data as Data).write(to: url, options: .atomic)
        return url
    }
}
