import Foundation
import PDFKit
import XCTest
@testable import BookletMakerPlugin

// MARK: - PDF Inspector Tests

final class PDFInspectorTests: XCTestCase {

    func testInspectorReadsPageCount() async throws {
        let url = try makeTempPDF(pageCount: 4)
        defer { try? FileManager.default.removeItem(at: url) }

        let inspector = PDFInspector()
        let info = try await inspector.inspect(url)
        XCTAssertEqual(info.pageCount, 4)
        // PDFKit writes pages with a default letter-ish size (612×792);
        // we only assert that we got a non-zero size back.
        XCTAssertGreaterThan(info.firstPageSize.width, 0)
        XCTAssertGreaterThan(info.firstPageSize.height, 0)
    }

    func testInspectorUsesVisibleCropBoxInsteadOfLandscapeMediaBox() async throws {
        let url = try makeCroppedSpreadPDF()
        defer { try? FileManager.default.removeItem(at: url) }

        let info = try await PDFInspector().inspect(url)

        XCTAssertEqual(info.pageCount, 1)
        XCTAssertEqual(info.firstPageSize.width, 386, accuracy: 1)
        XCTAssertEqual(info.firstPageSize.height, 594, accuracy: 1)
        XCTAssertLessThan(info.firstPageSize.width / info.firstPageSize.height, 1)
    }

    func testInspectorRejectsMissingFile() async {
        let url = URL(fileURLWithPath: "/tmp/does-not-exist-\(UUID()).pdf")
        let inspector = PDFInspector()
        do {
            _ = try await inspector.inspect(url)
            XCTFail("Expected error for missing file")
        } catch {
            // expected
        }
    }

    // MARK: - Helpers

    private func makeTempPDF(pageCount: Int) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("inspector-test-\(UUID().uuidString).pdf")
        let doc = PDFDocument()
        for _ in 0..<pageCount {
            let page = PDFPage()
            doc.insert(page, at: doc.pageCount)
        }
        guard doc.write(to: url) else {
            throw NSError(domain: "PDFInspectorTest", code: 1)
        }
        return url
    }

    private func makeCroppedSpreadPDF() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("inspector-crop-test-\(UUID().uuidString).pdf")
        let data = NSMutableData()
        var mediaBox = CGRect(x: 0, y: 0, width: 842, height: 595)
        let cropBox = CGRect(x: 421, y: 1, width: 386, height: 594)
        guard let consumer = CGDataConsumer(data: data),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw NSError(domain: "PDFInspectorTest", code: 2)
        }
        context.beginPDFPage(nil)
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(mediaBox)
        context.endPDFPage()
        context.closePDF()
        guard let document = PDFDocument(data: data as Data),
              let page = document.page(at: 0) else {
            throw NSError(domain: "PDFInspectorTest", code: 3)
        }
        page.setBounds(cropBox, for: .cropBox)
        guard document.write(to: url) else {
            throw NSError(domain: "PDFInspectorTest", code: 4)
        }
        return url
    }
}
