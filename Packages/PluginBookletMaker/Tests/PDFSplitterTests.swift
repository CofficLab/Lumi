import CoreGraphics
import Foundation
import PDFKit
import XCTest
@testable import BookletMakerPlugin

final class PDFSplitterTests: XCTestCase {
    func testSplitWritesOnePDFPerRange() async throws {
        let sourceURL = try makeSourcePDF(pageCount: 8)
        let outputDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("pdf-splitter-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: sourceURL)
            try? FileManager.default.removeItem(at: outputDirectory)
        }

        let segments = PDFSplitPlan.segments(pageCount: 8, cutPoints: [2, 5])
        let outputs = segments.map { segment in
            PDFSplitOutput(
                segment: segment,
                fileName: segment.index == 2
                    ? "middle-chapter.pdf"
                    : segment.fileName(baseName: "story")
            )
        }
        let urls = try await PDFSplitter().split(
            sourceURL: sourceURL,
            outputDirectory: outputDirectory,
            outputs: outputs
        )

        XCTAssertEqual(urls.map(\.lastPathComponent), [
            "story-part-1.pdf",
            "middle-chapter.pdf",
            "story-part-3.pdf",
        ])
        XCTAssertEqual(try urls.map { try XCTUnwrap(PDFDocument(url: $0)).pageCount }, [2, 3, 3])
    }

    func testSplitRefusesToOverwriteExistingOutput() async throws {
        let sourceURL = try makeSourcePDF(pageCount: 4)
        let outputDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("pdf-splitter-existing-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        let existing = outputDirectory.appendingPathComponent("story-part-1.pdf")
        try Data("existing".utf8).write(to: existing)
        defer {
            try? FileManager.default.removeItem(at: sourceURL)
            try? FileManager.default.removeItem(at: outputDirectory)
        }

        do {
            _ = try await PDFSplitter().split(
                sourceURL: sourceURL,
                outputDirectory: outputDirectory,
                outputs: PDFSplitPlan.segments(pageCount: 4, cutPoints: [2]).map {
                    PDFSplitOutput(segment: $0, fileName: $0.fileName(baseName: "story"))
                }
            )
            XCTFail("Expected existing output to be rejected")
        } catch {
            XCTAssertEqual(try Data(contentsOf: existing), Data("existing".utf8))
        }
    }

    private func makeSourcePDF(pageCount: Int) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("split-source-\(UUID().uuidString).pdf")
        let data = NSMutableData()
        var mediaBox = CGRect(x: 0, y: 0, width: 595, height: 842)
        guard let consumer = CGDataConsumer(data: data),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw NSError(domain: "PDFSplitterTests", code: 1)
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
