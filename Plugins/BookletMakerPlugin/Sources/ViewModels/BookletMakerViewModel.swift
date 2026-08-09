import AppKit
import Combine
import CoreGraphics
import Foundation
import os
import SuperLogKit
import SwiftUI

// MARK: - Booklet Maker View Model

/// Drives the PDF tools workspace view.
///
/// The view model is the single source of truth for the current
/// input PDF, the user's settings, render progress and the produced
/// thumbnails. It owns three collaborators:
/// - `PDFInspector` to read the source PDF,
/// - `BookletRenderer` to produce the impositioned PDF,
/// - `BookletThumbnailer` to render preview PNGs.
@MainActor
final class BookletMakerViewModel: ObservableObject, SuperLog {

    // MARK: - Identity

    nonisolated static let emoji = "📖"
    nonisolated static let verbose: Bool = false
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.booklet-maker.view-model"
    )

    // MARK: - Collaborators

    private let inspector  = PDFInspector()
    private let renderer   = BookletRenderer()
    private let splitter   = PDFSplitter()
    private let thumbnailer = BookletThumbnailer()
    private let demoDocument: CurrentPDFDocument

    private var renderTask: Task<Void, Never>?
    private var splitTask: Task<[URL], Error>?
    private var loadRequestID = UUID()
    private var securityScopedURL: URL?

    // MARK: - Published state

    /// The authoritative document used by preview, layout and export.
    @Published private(set) var currentDocument: CurrentPDFDocument

    /// Tool currently displayed in the rail and workspace.
    @Published var selectedTool: PDFTool = .booklet

    /// Current imposition settings.
    @Published var settings: BookletSettings = .init()

    /// Comma- or whitespace-separated pages after which a split occurs.
    @Published var splitCutPointsText: String = "" {
        didSet {
            if splitCutPointsText != oldValue {
                lastSplitOutputURLs = []
            }
        }
    }

    /// Render progress in 0.0 ... 1.0. 0 when idle.
    @Published private(set) var progress: Double = 0

    /// True while a render is in flight.
    @Published private(set) var isRendering: Bool = false

    /// URL of the most recent successful export.
    @Published private(set) var lastOutputURL: URL?

    /// Files produced by the most recent successful split.
    @Published private(set) var lastSplitOutputURLs: [URL] = []

    /// Generated preview thumbnails.
    @Published private(set) var thumbnails: [BookletThumbnailer.Thumbnail] = []

    /// Last error message, if any.
    @Published var errorMessage: String?

    // MARK: - Init

    init() {
        do {
            let demo = try DemoPDFProvider.makeDocument()
            demoDocument = demo
            _currentDocument = Published(initialValue: demo)
        } catch {
            preconditionFailure("Unable to create Booklet Maker demo PDF: \(error)")
        }
    }

    // MARK: - Derived

    /// Physical pieces of paper required by the current layout.
    var expectedSheetCount: Int {
        return BookletLayoutEngine.buildPhysicalSheets(
            inputPageCount: currentDocument.pageCount,
            settings: settings
        ).count
    }

    /// PDF pages / print sides produced by the current layout.
    var expectedOutputPageCount: Int {
        return BookletLayoutEngine.buildOutputSides(
            inputPageCount: currentDocument.pageCount,
            settings: settings
        ).count
    }

    var hasUserInput: Bool { !currentDocument.isDemo }
    var canExportBooklet: Bool {
        !isRendering
            && FileManager.default.fileExists(atPath: currentDocument.url.path)
    }

    var splitCutPointsResult: Result<[Int], PDFSplitPlan.ValidationError> {
        PDFSplitPlan.parseCutPoints(
            splitCutPointsText,
            pageCount: currentDocument.pageCount
        )
    }

    var splitCutPoints: [Int] {
        guard case .success(let points) = splitCutPointsResult else { return [] }
        return points
    }

    var splitSegments: [PDFSplitSegment] {
        PDFSplitPlan.segments(
            pageCount: currentDocument.pageCount,
            cutPoints: splitCutPoints
        )
    }

    var splitValidationMessage: String? {
        guard case .failure(let error) = splitCutPointsResult else { return nil }
        return error.errorDescription
    }

    var canExportSplit: Bool {
        !isRendering
            && !splitCutPoints.isEmpty
            && splitValidationMessage == nil
            && FileManager.default.fileExists(atPath: currentDocument.url.path)
    }

    var canExport: Bool {
        switch selectedTool {
        case .booklet: canExportBooklet
        case .split: canExportSplit
        }
    }

    // MARK: - Input handling

    /// Load a PDF. Cancels any in-flight work, then inspects the file.
    func loadPDF(_ url: URL) async {
        cancel()
        errorMessage = nil
        progress = 0
        thumbnails = []
        lastOutputURL = nil
        lastSplitOutputURLs = []

        let requestID = UUID()
        loadRequestID = requestID
        let didStartSecurityScope = url.startAccessingSecurityScopedResource()

        do {
            let info = try await inspector.inspect(url)
            guard loadRequestID == requestID else {
                if didStartSecurityScope { url.stopAccessingSecurityScopedResource() }
                return
            }

            releaseSecurityScope()
            securityScopedURL = didStartSecurityScope ? url : nil
            currentDocument = CurrentPDFDocument(
                source: .user,
                url: url,
                info: info
            )
            splitCutPointsText = ""
            Self.logger.info("\(Self.t)Loaded \(url.lastPathComponent) — \(info.pageCount) pages")
        } catch {
            if didStartSecurityScope { url.stopAccessingSecurityScopedResource() }
            guard loadRequestID == requestID else { return }
            let message = (error as? LocalizedError)?.errorDescription
                ?? error.localizedDescription
            errorMessage = message
            Self.logger.error("\(Self.t)Inspection failed: \(message)")
        }
    }

    /// Clear the user selection and return to the built-in demo document.
    func clear() {
        loadRequestID = UUID()
        cancel()
        releaseSecurityScope()
        currentDocument = demoDocument
        progress = 0
        thumbnails = []
        lastOutputURL = nil
        lastSplitOutputURLs = []
        splitCutPointsText = ""
        errorMessage = nil
    }

    // MARK: - Export

    /// Render the impositioned PDF to `outputURL`.
    func export(to outputURL: URL) async {
        let inputURL = currentDocument.url

        cancel()
        isRendering = true
        progress = 0
        thumbnails = []
        lastOutputURL = nil
        lastSplitOutputURLs = []
        errorMessage = nil

        let settings = self.settings
        let stream = renderer.render(sourceURL: inputURL,
                                     outputURL: outputURL,
                                     settings: settings)
        renderTask = Task { [weak self] in
            for await p in stream {
                guard let self else { return }
                await MainActor.run {
                    self.progress = p
                }
            }
            // Render is finished (or errored). Decide outcome.
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.isRendering = false
                let fileExists = FileManager.default.fileExists(atPath: outputURL.path)
                if fileExists {
                    self.lastOutputURL = outputURL
                    Self.logger.info("\(Self.t)Export complete: \(outputURL.lastPathComponent)")
                } else {
                    self.errorMessage = BookletLocalization.string("Export failed — see log for details.")
                }
            }
        }

        // Wait for the task to finish before kicking off thumbnails.
        await renderTask?.value
        if let _ = lastOutputURL {
            await refreshThumbnails(for: outputURL)
        }
    }

    /// Export all currently planned page ranges into `outputDirectory`.
    func exportSplit(to outputDirectory: URL) async {
        guard canExportSplit else { return }
        let segments = splitSegments
        let sourceURL = currentDocument.url
        let baseName = currentDocument.baseFileName

        cancel()
        isRendering = true
        progress = 0
        lastOutputURL = nil
        lastSplitOutputURLs = []
        errorMessage = nil

        let task = Task {
            try await splitter.split(
                sourceURL: sourceURL,
                outputDirectory: outputDirectory,
                baseName: baseName,
                segments: segments
            )
        }
        splitTask = task

        do {
            let urls = try await task.value
            guard !Task.isCancelled else { return }
            lastSplitOutputURLs = urls
            progress = 1
            Self.logger.info("\(Self.t)Split export complete: \(urls.count) files")
        } catch is CancellationError {
            // Cancellation is an expected result when switching documents/tools.
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? error.localizedDescription
            Self.logger.error("\(Self.t)Split export failed: \(self.errorMessage ?? "unknown error")")
        }
        splitTask = nil
        isRendering = false
    }

    /// Add or remove a split immediately after `pageNumber`.
    func toggleSplit(after pageNumber: Int) {
        guard pageNumber >= 1, pageNumber < currentDocument.pageCount else { return }
        var points = Set(splitCutPoints)
        if points.contains(pageNumber) {
            points.remove(pageNumber)
        } else {
            points.insert(pageNumber)
        }
        splitCutPointsText = points.sorted().map(String.init).joined(separator: ", ")
        lastSplitOutputURLs = []
        errorMessage = nil
    }

    /// Cancel the current render, if any.
    func cancel() {
        renderTask?.cancel()
        renderTask = nil
        splitTask?.cancel()
        splitTask = nil
        isRendering = false
    }

    // MARK: - Thumbnails

    /// Re-render the preview thumbnails for the just-exported PDF.
    private func refreshThumbnails(for outputURL: URL) async {
        let dir = BookletMakerRuntimeBridge.directoryURL
            ?? FileManager.default.temporaryDirectory
            .appendingPathComponent("BookletMakerThumbnails", isDirectory: true)
        thumbnails = await thumbnailer.makeThumbnails(
            fromPDF: outputURL,
            count: 5,
            outputDirectory: dir
        )
    }

    // MARK: - Finder helper

    /// Reveal a file in Finder. Silently no-ops if Finder can't be reached.
    func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func releaseSecurityScope() {
        securityScopedURL?.stopAccessingSecurityScopedResource()
        securityScopedURL = nil
    }

    deinit {
        securityScopedURL?.stopAccessingSecurityScopedResource()
    }
}
