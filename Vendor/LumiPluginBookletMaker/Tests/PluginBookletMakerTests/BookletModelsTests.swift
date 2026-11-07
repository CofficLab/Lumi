import CoreGraphics
import Foundation
import XCTest
import BookletMakerCore
@testable import PluginBookletMaker

/// Coverage for the plugin's plain value models. These types carry no
/// behaviour beyond derived presentation values and identity, so the tests
/// pin down exactly that: stable identity, non-empty presentation strings,
/// and the derived numbers the UI and the export pipeline both read.
final class BookletModelsTests: XCTestCase {

    // MARK: - PDFTool

    func testEveryToolHasDistinctIdentity() {
        XCTAssertEqual(PDFTool.allCases.count, 3)
        XCTAssertEqual(Set(PDFTool.allCases.map(\.rawValue)).count, 3)
        for tool in PDFTool.allCases {
            XCTAssertEqual(tool.id, tool.rawValue, "\(tool) must derive its id from its raw value")
        }
    }

    func testDisplayOrderCoversEveryToolExactlyOnce() {
        XCTAssertEqual(
            PDFTool.displayOrder.count,
            PDFTool.allCases.count,
            "displayOrder must not drop or duplicate a tool"
        )
        XCTAssertEqual(Set(PDFTool.displayOrder), Set(PDFTool.allCases))
    }

    func testSplitIsListedAboveBookletInTheRail() {
        guard let splitIndex = PDFTool.displayOrder.firstIndex(of: .split),
              let bookletIndex = PDFTool.displayOrder.firstIndex(of: .booklet) else {
            return XCTFail("split and booklet must both appear in the display order")
        }
        XCTAssertLessThan(
            splitIndex,
            bookletIndex,
            "The split entry is documented to sit above the booklet entry in the rail"
        )
    }

    func testEveryToolHasPresentationCopyAndAnIcon() {
        for tool in PDFTool.allCases {
            XCTAssertFalse(tool.title.isEmpty, "\(tool) has no title")
            XCTAssertFalse(tool.subtitle.isEmpty, "\(tool) has no subtitle")
            XCTAssertFalse(tool.systemImage.isEmpty, "\(tool) has no SF Symbol name")
            XCTAssertEqual(tool.title, tool.title.trimmingCharacters(in: .whitespaces))
        }
    }

    func testToolIconsAreDistinct() {
        let icons = PDFTool.allCases.map(\.systemImage)
        XCTAssertEqual(
            Set(icons).count,
            icons.count,
            "Distinct tools need distinct icons to be told apart in the rail"
        )
    }

    // MARK: - BookletStage

    func testStagesAreOrderedFromLayoutToExport() {
        XCTAssertEqual(
            BookletStage.allCases,
            [.printLayout, .paperSelection, .cuttingMarks, .bindingEffect, .review, .export]
        )
        XCTAssertEqual(
            BookletStage.allCases.map(\.stepNumber),
            Array(1...BookletStage.allCases.count),
            "Step numbers must be dense and 1-based"
        )
    }

    func testStageComparisonFollowsStepNumber() {
        XCTAssertTrue(BookletStage.review.isAfter(.printLayout))
        XCTAssertTrue(BookletStage.export.isAfter(.export) == false)
        XCTAssertFalse(BookletStage.printLayout.isAfter(.export))
        XCTAssertFalse(BookletStage.review.isAfter(.review))
    }

    func testEveryStageHasCopyAndAnIcon() {
        for stage in BookletStage.allCases {
            XCTAssertFalse(stage.title.isEmpty, "\(stage) has no title")
            XCTAssertFalse(stage.systemImage.isEmpty, "\(stage) has no SF Symbol name")
            XCTAssertEqual(stage.id, stage.rawValue)
        }
        let titles = BookletStage.allCases.map(\.title)
        XCTAssertEqual(Set(titles).count, titles.count, "Stage titles must be distinct")
    }

    // MARK: - SampleStory

    func testSampleStoryPageCountMatchesItsPages() {
        XCTAssertEqual(
            SampleStory.pages.count,
            SampleStory.pageCount,
            "pageCount is used to build the demo PDF, so it must match the page list"
        )
    }

    func testSampleStoryPagesAreOneBasedAndContiguous() {
        XCTAssertEqual(
            SampleStory.pages.map(\.id),
            Array(1...SampleStory.pageCount),
            "Story page ids must be 1-based and contiguous"
        )
    }

    func testSampleStoryLookupByNumber() {
        for page in SampleStory.pages {
            XCTAssertEqual(SampleStory.page(page.id)?.title, page.title)
        }
        XCTAssertNil(SampleStory.page(0))
        XCTAssertNil(SampleStory.page(-1))
        XCTAssertNil(SampleStory.page(SampleStory.pageCount + 1))
    }

    func testEverySampleStoryPageHasDistinctContent() {
        let titles = SampleStory.pages.map(\.title)
        let icons = SampleStory.pages.map(\.icon)
        XCTAssertEqual(Set(titles).count, titles.count, "Page titles must be distinguishable")
        XCTAssertEqual(Set(icons).count, icons.count, "Page icons must be distinguishable")
        for page in SampleStory.pages {
            XCTAssertFalse(page.title.isEmpty)
            XCTAssertFalse(page.body.isEmpty)
            XCTAssertFalse(page.icon.isEmpty)
        }
    }

    // MARK: - CurrentPDFDocument

    private func makeDocument(
        source: CurrentPDFDocument.Source = .user,
        path: String = "/tmp/story.pdf",
        pageCount: Int = 8,
        pageSize: CGSize = CGSize(width: 595, height: 842)
    ) -> CurrentPDFDocument {
        CurrentPDFDocument(
            source: source,
            url: URL(fileURLWithPath: path),
            info: PDFInspector.PDFInfo(pageCount: pageCount, firstPageSize: pageSize)
        )
    }

    func testDocumentReportsItsSourceAndPageCount() {
        XCTAssertTrue(makeDocument(source: .demo).isDemo)
        XCTAssertFalse(makeDocument(source: .user).isDemo)
        XCTAssertEqual(makeDocument(pageCount: 12).pageCount, 12)
    }

    func testDocumentsGetDistinctIdentities() {
        let first = makeDocument()
        let second = makeDocument()
        XCTAssertNotEqual(first.id, second.id, "SwiftUI list identity depends on a fresh id")
    }

    func testAspectRatioComesFromTheInspectedFirstPage() {
        let portrait = makeDocument(pageSize: CGSize(width: 595, height: 842))
        XCTAssertEqual(portrait.pageAspectRatio, 595.0 / 842.0, accuracy: 0.0001)
    }

    func testDegeneratePageSizeFallsBackToA4Proportions() {
        for size in [CGSize.zero, CGSize(width: 0, height: 842), CGSize(width: 595, height: 0)] {
            let document = makeDocument(pageSize: size)
            XCTAssertEqual(
                document.pageAspectRatio,
                1 / 1.414,
                accuracy: 0.0001,
                "A \(size) page must fall back to the default aspect ratio"
            )
        }
    }

    func testBaseFileNameDropsTheExtension() {
        let document = makeDocument(path: "/tmp/My Chapter.v2.pdf")
        XCTAssertEqual(document.baseFileName, "My Chapter.v2")
    }

    func testBaseFileNameHandlesNamesWithoutExtensions() {
        let document = makeDocument(path: "/tmp/plainname")
        XCTAssertEqual(document.baseFileName, "plainname")
    }

    // MARK: - Merge queue item

    func testMergeItemsGetDistinctIdentities() {
        let url = URL(fileURLWithPath: "/tmp/a.pdf")
        let first = PDFMergeItem(url: url, pageCount: 2)
        let second = PDFMergeItem(url: url, pageCount: 2)

        XCTAssertNotEqual(
            first.id,
            second.id,
            "Two queue entries for the same file must not share a SwiftUI identity"
        )
    }

    func testMergeItemPreservesItsInput() {
        let url = URL(fileURLWithPath: "/tmp/b.pdf")
        let item = PDFMergeItem(url: url, pageCount: 7)
        XCTAssertEqual(item.url, url)
        XCTAssertEqual(item.pageCount, 7)
    }

    func testMergeItemEqualityIgnoresTheGeneratedIdentity() {
        let url = URL(fileURLWithPath: "/tmp/c.pdf")
        let first = PDFMergeItem(url: url, pageCount: 3)
        let second = PDFMergeItem(url: url, pageCount: 3)

        // Equatable is synthesised over every stored property, so this
        // documents that two distinct entries for one file are never equal.
        XCTAssertNotEqual(first, second)
    }

    // MARK: - Export job

    func testBookletJobCapturesAnImmutableSettingsSnapshot() {
        var settings = BookletSettings()
        let job = PDFExportJob(
            id: UUID(),
            documentID: UUID(),
            sourceURL: URL(fileURLWithPath: "/tmp/story.pdf"),
            kind: .booklet(settings: settings),
            outputDirectory: URL(fileURLWithPath: "/tmp/out", isDirectory: true)
        )

        settings.outputPaper = .a5

        guard case .booklet(let captured) = job.kind else {
            return XCTFail("Expected a booklet job")
        }
        XCTAssertEqual(
            captured.outputPaper,
            .a4,
            "The job must keep the settings it was created with, not follow later edits"
        )
    }

    func testSplitJobCarriesItsOrderedOutputs() {
        let segments = [
            PDFSplitSegment(index: 1, startPage: 1, endPage: 2),
            PDFSplitSegment(index: 2, startPage: 3, endPage: 8),
        ]
        let outputs = segments.map { PDFSplitOutput(segment: $0, fileName: $0.fileName(baseName: "story")) }
        let job = PDFExportJob(
            id: UUID(),
            documentID: UUID(),
            sourceURL: URL(fileURLWithPath: "/tmp/story.pdf"),
            kind: .split(outputs: outputs),
            outputDirectory: URL(fileURLWithPath: "/tmp/out", isDirectory: true)
        )

        guard case .split(let captured) = job.kind else {
            return XCTFail("Expected a split job")
        }
        XCTAssertEqual(captured.map(\.fileName), ["story-part-1.pdf", "story-part-2.pdf"])
        XCTAssertEqual(captured.map(\.segment.pageCount), [2, 6])
    }

    func testExportResultCarriesItsJobIdentity() {
        let jobID = UUID()
        let result = PDFExportResult(
            jobID: jobID,
            urls: [URL(fileURLWithPath: "/tmp/out.pdf")]
        )

        XCTAssertEqual(result.jobID, jobID)
        XCTAssertEqual(result.urls.count, 1)
    }

    func testExportResultCanCarrySeveralFiles() {
        let result = PDFExportResult(
            jobID: UUID(),
            urls: [
                URL(fileURLWithPath: "/tmp/out-1.pdf"),
                URL(fileURLWithPath: "/tmp/out-2.pdf"),
                URL(fileURLWithPath: "/tmp/out-3.pdf"),
            ]
        )

        XCTAssertEqual(result.urls.map(\.lastPathComponent), ["out-1.pdf", "out-2.pdf", "out-3.pdf"])
    }
}
