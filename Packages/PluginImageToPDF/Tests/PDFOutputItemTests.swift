import XCTest
@testable import ImageToPDFPlugin

final class PDFOutputItemTests: XCTestCase {
    func testInitialStatusIsPending() {
        let source = ImageItem(url: URL(fileURLWithPath: "/tmp/a.png"), fileSize: 0)
        let item = PDFOutputItem(source: source)
        XCTAssertEqual(item.status, .pending)
        XCTAssertEqual(item.progress, 0)
    }

    func testDoneStatusExposesOutputURL() {
        let source = ImageItem(url: URL(fileURLWithPath: "/tmp/a.png"), fileSize: 0)
        var item = PDFOutputItem(source: source)
        let url = URL(fileURLWithPath: "/tmp/a.pdf")
        item.status = .done(url)

        if case let .done(returned) = item.status {
            XCTAssertEqual(returned, url)
        } else {
            XCTFail("Expected .done case")
        }
    }

    func testFailedStatusIsTerminal() {
        let source = ImageItem(url: URL(fileURLWithPath: "/tmp/a.png"), fileSize: 0)
        var item = PDFOutputItem(source: source)
        item.status = .failed("boom")
        XCTAssertTrue(item.status.isTerminal)
    }
}