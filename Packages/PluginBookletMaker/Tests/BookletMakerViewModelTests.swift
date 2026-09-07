import CoreGraphics
import Foundation
import PDFKit
import XCTest
@testable import BookletMakerPlugin

// MARK: - Controlled service doubles

/// A renderer stub whose completion is controlled by the test. It is not
/// cancellation-cooperative on purpose: a late successful return simulates
/// a service that finished after being cancelled, which the view model must
/// refuse to apply.
@MainActor
private final class ControlledRenderer: BookletRendering {
    struct Call {
        let sourceURL: URL
        let outputURL: URL
        let settings: BookletSettings
        let progress: @Sendable (Double) -> Void
    }

    private(set) var calls: [Call] = []
    var onRender: ((Call) async throws -> URL)?

    func render(sourceURL: URL,
                outputURL: URL,
                settings: BookletSettings,
                progress: @escaping @Sendable (Double) -> Void) async throws -> URL {
        let call = Call(sourceURL: sourceURL, outputURL: outputURL, settings: settings, progress: progress)
        calls.append(call)
        guard let onRender else {
            throw BookletRenderer.RenderError.sourceUnreadable(sourceURL)
        }
        return try await onRender(call)
    }
}

/// A splitter stub with the same controlled-completion semantics.
@MainActor
private final class ControlledSplitter: PDFSplitting {
    struct Call {
        let sourceURL: URL
        let outputDirectory: URL
        let outputs: [PDFSplitOutput]
        let progress: @Sendable (Double) -> Void
    }

    private(set) var calls: [Call] = []
    var onSplit: ((Call) async throws -> [URL])?

    func split(sourceURL: URL,
               outputDirectory: URL,
               outputs: [PDFSplitOutput],
               progress: @escaping @Sendable (Double) -> Void) async throws -> [URL] {
        let call = Call(sourceURL: sourceURL, outputDirectory: outputDirectory, outputs: outputs, progress: progress)
        calls.append(call)
        guard let onSplit else {
            throw PDFSplitter.SplitError.sourceUnreadable(sourceURL)
        }
        return try await onSplit(call)
    }
}

// MARK: - View Model Tests

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

    func testSplitToolPlansAndExportsCurrentDocument() async throws {
        let sourceURL = try makeSourcePDF(pageCount: 8)
        let outputDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("view-model-split-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: sourceURL)
            try? FileManager.default.removeItem(at: outputDirectory)
        }
        let viewModel = BookletMakerViewModel()
        await viewModel.loadPDF(sourceURL)
        viewModel.selectedTool = .split
        viewModel.splitCutPointsText = "2, 5"

        XCTAssertTrue(viewModel.canExport)
        XCTAssertEqual(viewModel.splitSegments.map(\.pageCount), [2, 3, 3])
        viewModel.renameSplitOutput(viewModel.splitSegments[1], to: "middle-chapter")
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        XCTAssertEqual(viewModel.splitOutputs.map(\.fileName), [
            "\(baseName)-part-1.pdf",
            "middle-chapter.pdf",
            "\(baseName)-part-3.pdf",
        ])

        await viewModel.exportSplit(to: outputDirectory)

        XCTAssertEqual(viewModel.lastSplitOutputURLs.count, 3)
        XCTAssertEqual(viewModel.lastSplitOutputURLs[1].lastPathComponent, "middle-chapter.pdf")
        XCTAssertNil(viewModel.errorMessage)
    }

    func testSplitOutputNamesMustBeNonEmptyAndUnique() {
        let viewModel = BookletMakerViewModel()
        viewModel.selectedTool = .split
        viewModel.splitCutPointsText = "2, 5"
        let segments = viewModel.splitSegments

        viewModel.renameSplitOutput(segments[0], to: "")
        XCTAssertNotNil(viewModel.splitFileNameValidationMessage(for: segments[0]))
        XCTAssertFalse(viewModel.canExportSplit)

        viewModel.renameSplitOutput(segments[0], to: "same")
        viewModel.renameSplitOutput(segments[1], to: "SAME.pdf")
        XCTAssertNotNil(viewModel.splitFileNameValidationMessage(for: segments[0]))
        XCTAssertFalse(viewModel.canExportSplit)
    }

    func testSplitCutPointToggleKeepsTextAndPlanInSync() {
        let viewModel = BookletMakerViewModel()
        viewModel.selectedTool = .split

        viewModel.toggleSplit(after: 2)
        viewModel.toggleSplit(after: 5)
        XCTAssertEqual(viewModel.splitCutPointsText, "2, 5")
        XCTAssertEqual(viewModel.splitSegments.map(\.pageCount), [2, 3, 3])

        viewModel.toggleSplit(after: 2)
        XCTAssertEqual(viewModel.splitCutPointsText, "5")
        XCTAssertEqual(viewModel.splitSegments.map(\.pageCount), [5, 3])
    }

    func testDuplicateSplitFileNamesAreRejected() {
        let viewModel = BookletMakerViewModel()
        viewModel.selectedTool = .split
        viewModel.splitCutPointsText = "2"
        XCTAssertEqual(viewModel.splitSegments.count, 2)

        let first = viewModel.splitSegments[0]
        let second = viewModel.splitSegments[1]
        viewModel.renameSplitOutputStem(first, to: "same-name")
        viewModel.renameSplitOutputStem(second, to: "same-name")

        XCTAssertNotNil(viewModel.splitFileNameValidationMessage)
        XCTAssertFalse(viewModel.canExportSplit)

        viewModel.renameSplitOutputStem(second, to: "other-name")
        XCTAssertNil(viewModel.splitFileNameValidationMessage)
        XCTAssertTrue(viewModel.canExportSplit)
    }

    func testSplitSegmentRangeLabel() {
        let segment = PDFSplitSegment(index: 0, startPage: 3, endPage: 5)
        XCTAssertEqual(segment.pageCount, 3)
        XCTAssertEqual(segment.rangeKey, "3-5")
        XCTAssertFalse(segment.rangeLabel.isEmpty)

        let single = PDFSplitSegment(index: 1, startPage: 7, endPage: 7)
        XCTAssertFalse(single.rangeLabel.isEmpty)
    }

    // MARK: - Export job isolation and cancellation

    func testLateOldExportCannotOverwriteNewerExport() async throws {
        let renderer = ControlledRenderer()
        let viewModel = BookletMakerViewModel(renderer: renderer)

        // Job A hangs until the test releases it.
        var releaseA: CheckedContinuation<Void, Never>?
        renderer.onRender = { call in
            await withCheckedContinuation { releaseA = $0 }
            return call.outputURL
        }

        let outputA = FileManager.default.temporaryDirectory
            .appendingPathComponent("late-old-a-\(UUID().uuidString).pdf")
        let outputB = FileManager.default.temporaryDirectory
            .appendingPathComponent("late-old-b-\(UUID().uuidString).pdf")
        defer {
            try? FileManager.default.removeItem(at: outputA)
            try? FileManager.default.removeItem(at: outputB)
        }

        let exportA = Task { await viewModel.export(to: outputA) }
        while renderer.calls.isEmpty { await Task.yield() }
        XCTAssertTrue(viewModel.isRendering)

        // Job B starts (cancelling A internally) and completes immediately.
        renderer.onRender = { call in call.outputURL }
        await viewModel.export(to: outputB)
        XCTAssertEqual(viewModel.lastOutputURL, outputB)
        XCTAssertFalse(viewModel.isRendering)

        // Stale A finally "completes" — it must not touch any state.
        releaseA?.resume()
        await exportA.value
        XCTAssertEqual(viewModel.lastOutputURL, outputB)
        XCTAssertFalse(viewModel.isRendering)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testCancelledExportHasNoSuccessResult() async throws {
        let renderer = ControlledRenderer()
        let viewModel = BookletMakerViewModel(renderer: renderer)

        var releaseA: CheckedContinuation<Void, Never>?
        renderer.onRender = { call in
            await withCheckedContinuation { releaseA = $0 }
            return call.outputURL
        }

        let outputA = FileManager.default.temporaryDirectory
            .appendingPathComponent("cancelled-a-\(UUID().uuidString).pdf")
        defer { try? FileManager.default.removeItem(at: outputA) }

        let exportTask = Task { await viewModel.export(to: outputA) }
        while renderer.calls.isEmpty { await Task.yield() }

        viewModel.cancel()
        XCTAssertTrue(viewModel.isCancelling)

        // The worker still returns a URL, but the job was cancelled.
        releaseA?.resume()
        await exportTask.value

        XCTAssertNil(viewModel.lastOutputURL)
        XCTAssertFalse(viewModel.isRendering)
        XCTAssertFalse(viewModel.isCancelling)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testExportFailureSurfacesErrorAndClearsBusyState() async throws {
        let renderer = ControlledRenderer()
        let viewModel = BookletMakerViewModel(renderer: renderer)
        renderer.onRender = { call in
            throw BookletRenderer.RenderError.writeFailed(call.outputURL)
        }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("failed-export-\(UUID().uuidString).pdf")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        await viewModel.export(to: outputURL)

        XCTAssertNil(viewModel.lastOutputURL)
        XCTAssertFalse(viewModel.isRendering)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    func testCancelledSplitThenNewSplitCompletesCleanly() async throws {
        let splitter = ControlledSplitter()
        let viewModel = BookletMakerViewModel(splitter: splitter)
        viewModel.selectedTool = .split
        viewModel.splitCutPointsText = "2, 5"

        var releaseA: CheckedContinuation<Void, Never>?
        splitter.onSplit = { call in
            await withCheckedContinuation { releaseA = $0 }
            return call.outputs.map { call.outputDirectory.appendingPathComponent($0.fileName) }
        }

        let directoryA = FileManager.default.temporaryDirectory
            .appendingPathComponent("late-old-split-a-\(UUID().uuidString)", isDirectory: true)
        let directoryB = FileManager.default.temporaryDirectory
            .appendingPathComponent("late-old-split-b-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directoryA)
            try? FileManager.default.removeItem(at: directoryB)
        }

        // Job A hangs until cancelled.
        let exportA = Task { await viewModel.exportSplit(to: directoryA) }
        while splitter.calls.isEmpty { await Task.yield() }
        XCTAssertTrue(viewModel.isRendering)

        // User cancels A; the worker still returns late, but no success may
        // be recorded and the busy state must unwind.
        viewModel.cancel()
        XCTAssertTrue(viewModel.isCancelling)
        releaseA?.resume()
        await exportA.value

        XCTAssertTrue(viewModel.lastSplitOutputURLs.isEmpty)
        XCTAssertFalse(viewModel.isRendering)
        XCTAssertFalse(viewModel.isCancelling)

        // A newer job B then runs to completion with fresh results.
        splitter.onSplit = { call in
            call.outputs.map { call.outputDirectory.appendingPathComponent($0.fileName) }
        }
        await viewModel.exportSplit(to: directoryB)

        XCTAssertEqual(viewModel.lastSplitOutputURLs.count, 3)
        XCTAssertTrue(viewModel.lastSplitOutputURLs[0].path.hasPrefix(directoryB.path))
        XCTAssertFalse(viewModel.isRendering)
        XCTAssertNil(viewModel.errorMessage)
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
