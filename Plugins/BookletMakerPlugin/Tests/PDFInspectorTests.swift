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
}
