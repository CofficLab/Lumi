import CoreGraphics
import Foundation
import PDFKit
import XCTest
import BookletMakerCore
@testable import PluginBookletMaker

/// Coverage for the two document-producing services.
///
/// `DemoPDFProvider` builds the built-in sample that every fresh session
/// starts with, and `BookletThumbnailer` renders the preview PNGs shown
/// after an export. Both write real files, so these tests assert on the
/// artefacts they leave on disk rather than on internal state.
final class BookletDocumentServicesTests: XCTestCase {

    private var scratchDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        scratchDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BookletDocumentServices-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: scratchDirectory, withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: scratchDirectory)
        try super.tearDownWithError()
    }

    // MARK: - Demo PDF

    func testDemoDocumentIsARealPDFOnDisk() throws {
        let demo = try DemoPDFProvider.makeDocument()

        XCTAssertTrue(demo.isDemo)
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: demo.url.path),
            "The demo must exist on disk so it travels the same preview pipeline as a user file"
        )
        XCTAssertEqual(demo.url.pathExtension.lowercased(), "pdf")
    }

    func testDemoDocumentPageCountMatchesTheStory() throws {
        let demo = try DemoPDFProvider.makeDocument()

        XCTAssertEqual(demo.pageCount, SampleStory.pageCount)
        let document = try XCTUnwrap(PDFDocument(url: demo.url), "Demo must be readable by PDFKit")
        XCTAssertEqual(
            document.pageCount,
            SampleStory.pageCount,
            "The rendered file must have one page per story page"
        )
    }

    func testDemoDocumentPageSizeIsTheDeclaredOne() throws {
        let demo = try DemoPDFProvider.makeDocument()

        XCTAssertEqual(demo.info.firstPageSize, CGSize(width: 595, height: 842))
        let document = try XCTUnwrap(PDFDocument(url: demo.url))
        let bounds = try XCTUnwrap(document.page(at: 1)).bounds(for: .mediaBox)
        XCTAssertEqual(bounds.width, 595, accuracy: 1)
        XCTAssertEqual(bounds.height, 842, accuracy: 1)
    }

    func testDemoDocumentIsActuallyDrawn() throws {
        let demo = try DemoPDFProvider.makeDocument()
        let document = try XCTUnwrap(PDFDocument(url: demo.url))
        let page = try XCTUnwrap(document.page(at: 1))
        let selection = page.selection(for: page.bounds(for: .cropBox))
        let extracted = page.string ?? ""

        XCTAssertFalse(
            extracted.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            "A blank demo would make the preview and the imposition diagrams meaningless"
        )
    }

    func testDemoDocumentIsReusedAcrossCalls() throws {
        let first = try DemoPDFProvider.makeDocument()
        let second = try DemoPDFProvider.makeDocument()

        XCTAssertEqual(
            first.url,
            second.url,
            "The cached demo path must be stable so a running build does not regenerate it"
        )
        let modified = try FileManager.default.attributesOfItem(atPath: first.url.path)[.modificationDate] as? Date
        _ = try DemoPDFProvider.makeDocument()
        let afterSecond = try FileManager.default.attributesOfItem(atPath: first.url.path)[.modificationDate] as? Date

        XCTAssertEqual(
            modified,
            afterSecond,
            "A valid demo on disk must be reused rather than rewritten"
        )
    }

    func testCorruptedDemoIsRebuilt() throws {
        let reference = try DemoPDFProvider.makeDocument()
        // Leave a truncated file where the demo belongs.
        try Data("not a pdf".utf8).write(to: reference.url, options: .atomic)

        let rebuilt = try DemoPDFProvider.makeDocument()

        XCTAssertEqual(rebuilt.url, reference.url)
        XCTAssertNotNil(
            PDFDocument(url: rebuilt.url),
            "An unreadable cached demo must be replaced with a valid one"
        )
        XCTAssertEqual(
            PDFDocument(url: rebuilt.url)?.pageCount,
            SampleStory.pageCount,
            "The rebuilt demo must have the full page count"
        )
    }

    func testDemoIsInspectedLikeAnyUserFile() async throws {
        let demo = try DemoPDFProvider.makeDocument()
        let info = try await PDFInspector().inspect(demo.url)

        XCTAssertEqual(info.pageCount, SampleStory.pageCount)
        XCTAssertEqual(info.firstPageSize.width, 595, accuracy: 1)
        XCTAssertEqual(info.firstPageSize.height, 842, accuracy: 1)
    }

    // MARK: - Thumbnails

    /// Build a small PDF to render thumbnails from.
    private func makeSourcePDF(pageCount: Int) throws -> URL {
        let url = scratchDirectory.appendingPathComponent("thumb-source-\(UUID().uuidString).pdf")
        let document = PDFDocument()
        for index in 0..<pageCount {
            let page = PDFPage(image: Self.pageImage(index: index)) ?? PDFPage()
            document.insert(page, at: document.pageCount)
        }
        XCTAssertTrue(document.write(to: url))
        return url
    }

    private static func pageImage(index: Int) -> NSImage {
        let size = CGSize(width: 200, height: 300)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.white.setFill()
        NSRect(origin: .zero, size: size).fill()
        NSColor.black.setFill()
        // A distinct block per page proves the thumbnails differ.
        let inset = CGFloat(index) * 20
        NSRect(x: 20 + inset, y: 20, width: 60, height: 60).fill()
        image.unlockFocus()
        return image
    }

    func testThumbnailsAreRenderedForTheRequestedPages() async throws {
        let source = try makeSourcePDF(pageCount: 6)
        let outputDirectory = scratchDirectory.appendingPathComponent("thumbs-a", isDirectory: true)

        let thumbnails = await BookletThumbnailer().makeThumbnails(
            fromPDF: source,
            count: 3,
            outputDirectory: outputDirectory
        )

        XCTAssertEqual(thumbnails.count, 3)
        XCTAssertEqual(thumbnails.map(\.sheetIndex), [0, 1, 2])
        for thumbnail in thumbnails {
            XCTAssertTrue(
                FileManager.default.fileExists(atPath: thumbnail.fileURL.path),
                "Thumbnail \(thumbnail.sheetIndex) was reported but not written"
            )
            XCTAssertEqual(thumbnail.fileURL.pathExtension.lowercased(), "png")
        }
    }

    func testThumbnailsAreNeverMoreThanTheDocumentPageCount() async throws {
        let source = try makeSourcePDF(pageCount: 2)
        let outputDirectory = scratchDirectory.appendingPathComponent("thumbs-b", isDirectory: true)

        let thumbnails = await BookletThumbnailer().makeThumbnails(
            fromPDF: source,
            count: 10,
            outputDirectory: outputDirectory
        )

        XCTAssertEqual(thumbnails.count, 2, "A 2-page document cannot yield 10 thumbnails")
    }

    func testZeroOrNegativeCountProducesNothing() async throws {
        let source = try makeSourcePDF(pageCount: 3)
        let thumbnailer = BookletThumbnailer()

        for count in [0, -1] {
            let thumbnails = await thumbnailer.makeThumbnails(
                fromPDF: source,
                count: count,
                outputDirectory: scratchDirectory.appendingPathComponent("thumbs-\(count)")
            )
            XCTAssertTrue(thumbnails.isEmpty, "count \(count) should render nothing")
        }
    }

    func testThumbnailDirectoryIsCreatedOnDemand() async throws {
        let source = try makeSourcePDF(pageCount: 2)
        // Nested and not yet created.
        let outputDirectory = scratchDirectory
            .appendingPathComponent("nested", isDirectory: true)
            .appendingPathComponent("thumbs", isDirectory: true)
        XCTAssertFalse(FileManager.default.fileExists(atPath: outputDirectory.path))

        let thumbnails = await BookletThumbnailer().makeThumbnails(
            fromPDF: source,
            count: 2,
            outputDirectory: outputDirectory
        )

        XCTAssertEqual(thumbnails.count, 2)
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputDirectory.path))
    }

    func testThumbnailFilesAreDistinctAndReadable() async throws {
        let source = try makeSourcePDF(pageCount: 3)
        let outputDirectory = scratchDirectory.appendingPathComponent("thumbs-c", isDirectory: true)

        let thumbnails = await BookletThumbnailer().makeThumbnails(
            fromPDF: source,
            count: 3,
            outputDirectory: outputDirectory
        )

        let paths = Set(thumbnails.map(\.fileURL.path))
        XCTAssertEqual(paths.count, 3, "Each page needs its own thumbnail file")

        for thumbnail in thumbnails {
            let data = try Data(contentsOf: thumbnail.fileURL)
            XCTAssertFalse(data.isEmpty)
            let image = try XCTUnwrap(NSImage(data: data), "Thumbnail must be a decodable image")
            XCTAssertGreaterThan(image.size.width, 0)
            XCTAssertGreaterThan(image.size.height, 0)
        }
    }

    func testUnreadablePDFYieldsNoThumbnails() async throws {
        let bogus = scratchDirectory.appendingPathComponent("broken.pdf")
        try Data("definitely not a pdf".utf8).write(to: bogus, options: .atomic)

        let thumbnails = await BookletThumbnailer().makeThumbnails(
            fromPDF: bogus,
            count: 5,
            outputDirectory: scratchDirectory.appendingPathComponent("thumbs-d")
        )

        XCTAssertTrue(
            thumbnails.isEmpty,
            "An unreadable PDF must degrade to an empty preview rather than fail"
        )
    }

    func testMissingPDFYieldsNoThumbnails() async throws {
        let missing = scratchDirectory.appendingPathComponent("missing.pdf")

        let thumbnails = await BookletThumbnailer().makeThumbnails(
            fromPDF: missing,
            count: 5,
            outputDirectory: scratchDirectory.appendingPathComponent("thumbs-e")
        )

        XCTAssertTrue(thumbnails.isEmpty)
    }

    func testRenderingSurvivesAnUnwritableOutputDirectory() async throws {
        let source = try makeSourcePDF(pageCount: 2)
        // A path whose parent is a regular file can never be a directory.
        let blocker = scratchDirectory.appendingPathComponent("blocker")
        try Data("x".utf8).write(to: blocker, options: .atomic)
        let outputDirectory = blocker.appendingPathComponent("thumbs", isDirectory: true)

        let thumbnails = await BookletThumbnailer().makeThumbnails(
            fromPDF: source,
            count: 2,
            outputDirectory: outputDirectory
        )

        XCTAssertTrue(
            thumbnails.isEmpty,
            "A preview that cannot be written must return nothing instead of throwing"
        )
    }
}