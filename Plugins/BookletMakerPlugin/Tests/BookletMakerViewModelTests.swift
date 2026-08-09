import CoreGraphics
import Foundation
import PDFKit
import XCTest
@testable import BookletMakerPlugin

@MainActor
final class BookletMakerViewModelTests: XCTestCase {
    func testStartsWithExportableDemoDocument() {
        let viewModel = BookletMakerViewModel()

        XCTAssertTrue(viewModel.currentDocument.isDemo)
        XCTAssertEqual(viewModel.currentDocument.pageCount, SampleStory.pageCount)
        XCTAssertFalse(viewModel.hasUserInput)
        XCTAssertTrue(viewModel.canExport)
        XCTAssertEqual(viewModel.expectedSheetCount, 2)
        XCTAssertEqual(viewModel.expectedOutputPageCount, 4)
    }

    func testSuccessfulUserSelectionBecomesCurrentAndClearRestoresDemo() async throws {
        let url = try makeSourcePDF(pageCount: 3)
        defer { try? FileManager.default.removeItem(at: url) }
        let viewModel = BookletMakerViewModel()

        await viewModel.loadPDF(url)

        XCTAssertFalse(viewModel.currentDocument.isDemo)
        XCTAssertEqual(viewModel.currentDocument.url, url)
        XCTAssertEqual(viewModel.currentDocument.pageCount, 3)
        XCTAssertTrue(viewModel.hasUserInput)
        XCTAssertEqual(viewModel.expectedSheetCount, 1)
        XCTAssertEqual(viewModel.expectedOutputPageCount, 2)

        viewModel.clear()

        XCTAssertTrue(viewModel.currentDocument.isDemo)
        XCTAssertEqual(viewModel.currentDocument.pageCount, SampleStory.pageCount)
        XCTAssertFalse(viewModel.hasUserInput)
        XCTAssertTrue(viewModel.canExport)
    }

    func testFailedSelectionPreservesCurrentDocument() async {
        let viewModel = BookletMakerViewModel()
        let originalID = viewModel.currentDocument.id
        let missingURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("missing-\(UUID().uuidString).pdf")

        await viewModel.loadPDF(missingURL)

        XCTAssertEqual(viewModel.currentDocument.id, originalID)
        XCTAssertTrue(viewModel.currentDocument.isDemo)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    func testDemoDocumentCanBeExported() async throws {
        let viewModel = BookletMakerViewModel()
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("demo-booklet-\(UUID().uuidString).pdf")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        await viewModel.export(to: outputURL)

        let output = try XCTUnwrap(PDFDocument(url: outputURL))
        XCTAssertEqual(output.pageCount, 4)
        XCTAssertEqual(viewModel.lastOutputURL, outputURL)
    }

    private func makeSourcePDF(pageCount: Int) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("current-document-\(UUID().uuidString).pdf")
        let data = NSMutableData()
        var mediaBox = CGRect(x: 0, y: 0, width: 595, height: 842)
        guard let consumer = CGDataConsumer(data: data),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw NSError(domain: "BookletMakerViewModelTests", code: 1)
        }

        for _ in 0..<pageCount {
            context.beginPDFPage(nil)
            context.setFillColor(gray: 1, alpha: 1)
            context.fill(mediaBox)
            context.endPDFPage()
        }
        context.closePDF()
        try (data as Data).write(to: url, options: .atomic)
        return url
    }
}
