import Combine
import CoreGraphics
import Foundation
import os
import KitSuperLog
import SwiftUI

#if canImport(AppKit)
import AppKit
#endif

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
    private let renderer: any BookletRendering
    private let splitter: any PDFSplitting
    private let thumbnailer = BookletThumbnailer()
    private let demoDocument: CurrentPDFDocument

    private var renderTask: Task<URL, Error>?
    private var splitTask: Task<[URL], Error>?
    private var thumbnailTask: Task<Void, Never>?
    private var loadRequestID = UUID()
    private var activeExportJobID: UUID?
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

    /// User-defined output names, keyed by the exact page range they describe.
    @Published private var splitFileNameOverrides: [String: String] = [:]

    /// Render progress in 0.0 ... 1.0. 0 when idle.
    @Published private(set) var progress: Double = 0

    /// True while a render is in flight.
    @Published private(set) var isRendering: Bool = false

    /// True while the exported PDF is being prepared for preview.
    @Published private(set) var isPreparingPreview: Bool = false

    /// True from a user-initiated cancel until the in-flight worker unwinds.
    @Published private(set) var isCancelling: Bool = false

    /// URL of the most recent successful export.
    @Published private(set) var lastOutputURL: URL?

    /// Files produced by the most recent successful split.
    @Published private(set) var lastSplitOutputURLs: [URL] = []

    /// Generated preview thumbnails.
    @Published private(set) var thumbnails: [BookletThumbnailer.Thumbnail] = []

    /// Last error message, if any.
    @Published var errorMessage: String?

    // MARK: - Init

    /// - Parameters:
    ///   - renderer: renderer override for tests. Defaults to `BookletRenderer`.
    ///   - splitter: splitter override for tests. Defaults to `PDFSplitter`.
    init(renderer: (any BookletRendering)? = nil,
         splitter: (any PDFSplitting)? = nil) {
        self.renderer = renderer ?? BookletRenderer()
        self.splitter = splitter ?? PDFSplitter()
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
    var isBusy: Bool { isRendering || isPreparingPreview }
    var canExportBooklet: Bool {
        !isBusy
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

    var splitOutputs: [PDFSplitOutput] {
        splitSegments.compactMap { segment in
            guard let fileName = canonicalSplitFileName(for: segment) else { return nil }
            return PDFSplitOutput(segment: segment, fileName: fileName)
        }
    }

    var splitValidationMessage: String? {
        guard case .failure(let error) = splitCutPointsResult else { return nil }
        return error.errorDescription
    }

    var splitFileNameValidationMessage: String? {
        splitSegments.compactMap(splitFileNameValidationMessage(for:)).first
    }

    var canExportSplit: Bool {
        !isBusy
            && !splitCutPoints.isEmpty
            && splitValidationMessage == nil
            && splitFileNameValidationMessage == nil
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
        cancelInternal()
        activeExportJobID = nil
        errorMessage = nil
        progress = 0
        thumbnails = []
        lastOutputURL = nil
        lastSplitOutputURLs = []
        splitFileNameOverrides = [:]

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
        cancelInternal()
        activeExportJobID = nil
        releaseSecurityScope()
        currentDocument = demoDocument
        progress = 0
        thumbnails = []
        lastOutputURL = nil
        lastSplitOutputURLs = []
        splitFileNameOverrides = [:]
        splitCutPointsText = ""
        errorMessage = nil
    }

    // MARK: - Export

    /// Render the impositioned PDF to `outputURL`.
    ///
    /// The job captures an immutable snapshot of the document and settings.
    /// Success is only recorded for the job that is still active; a late
    /// old job can never overwrite a newer job's state.
    func export(to outputURL: URL) async {
        cancelInternal()

        let jobID = UUID()
        activeExportJobID = jobID
        let sourceURL = currentDocument.url
        let settings = self.settings
        progress = 0
        thumbnails = []
        lastOutputURL = nil
        lastSplitOutputURLs = []
        errorMessage = nil
        isRendering = true
        isPreparingPreview = false
        isCancelling = false

        do {
            let task = Task { [renderer] in
                try await renderer.render(
                    sourceURL: sourceURL,
                    outputURL: outputURL,
                    settings: settings
                ) { [weak self] value in
                    Task { @MainActor in
                        guard let self,
                              self.activeExportJobID == jobID,
                              !self.isCancelling else { return }
                        self.progress = value
                    }
                }
            }
            renderTask = task
            let result = try await task.value
            renderTask = nil

            guard activeExportJobID == jobID else { return }
            if Task.isCancelled || isCancelling {
                // This job was cancelled; clean up its own state. A newer
                // job is never touched because it would own the active ID.
                isRendering = false
                isCancelling = false
                return
            }
            lastOutputURL = result
            isRendering = false
            progress = 1
            Self.logger.info("\(Self.t)Export complete: \(result.lastPathComponent)")
            // Thumbnails are prepared separately and must never turn a
            // successful export into a failure.
            startThumbnailPreparation(for: result, jobID: jobID)
        } catch is CancellationError {
            renderTask = nil
            guard activeExportJobID == jobID else { return }
            isRendering = false
            isCancelling = false
        } catch {
            renderTask = nil
            guard activeExportJobID == jobID else { return }
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? error.localizedDescription
            isRendering = false
            isCancelling = false
            Self.logger.error("\(Self.t)Export failed: \(error.localizedDescription)")
        }
    }

    /// Export all currently planned page ranges into `outputDirectory`.
    func exportSplit(to outputDirectory: URL) async {
        guard canExportSplit else { return }
        cancelInternal()

        let jobID = UUID()
        activeExportJobID = jobID
        let outputs = splitOutputs
        let sourceURL = currentDocument.url
        progress = 0
        thumbnails = []
        lastOutputURL = nil
        lastSplitOutputURLs = []
        errorMessage = nil
        isRendering = true
        isPreparingPreview = false
        isCancelling = false

        do {
            let task = Task { [splitter] in
                try await splitter.split(
                    sourceURL: sourceURL,
                    outputDirectory: outputDirectory,
                    outputs: outputs
                ) { [weak self] value in
                    Task { @MainActor in
                        guard let self,
                              self.activeExportJobID == jobID,
                              !self.isCancelling else { return }
                        self.progress = value
                    }
                }
            }
            splitTask = task
            let urls = try await task.value
            splitTask = nil

            guard activeExportJobID == jobID else { return }
            if Task.isCancelled || isCancelling {
                isRendering = false
                isCancelling = false
                return
            }
            lastSplitOutputURLs = urls
            progress = 1
            isRendering = false
            Self.logger.info("\(Self.t)Split export complete: \(urls.count) files")
        } catch is CancellationError {
            splitTask = nil
            guard activeExportJobID == jobID else { return }
            isRendering = false
            isCancelling = false
        } catch {
            splitTask = nil
            guard activeExportJobID == jobID else { return }
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? error.localizedDescription
            isRendering = false
            isCancelling = false
            Self.logger.error("\(Self.t)Split export failed: \(error.localizedDescription)")
        }
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

    /// Name shown in the result editor. The `.pdf` extension is optional while editing.
    func splitFileName(for segment: PDFSplitSegment) -> String {
        splitFileNameOverrides[segment.rangeKey]
            ?? segment.fileName(baseName: currentDocument.baseFileName)
    }

    func splitFileNameStem(for segment: PDFSplitSegment) -> String {
        let fileName = splitFileName(for: segment)
        guard fileName.lowercased().hasSuffix(".pdf") else { return fileName }
        return String(fileName.dropLast(4))
    }

    func renameSplitOutputStem(_ segment: PDFSplitSegment, to stem: String) {
        renameSplitOutput(segment, to: stem.isEmpty ? "" : stem + ".pdf")
    }

    /// Update one planned output name without changing its page range.
    func renameSplitOutput(_ segment: PDFSplitSegment, to fileName: String) {
        let defaultName = segment.fileName(baseName: currentDocument.baseFileName)
        if fileName == defaultName {
            splitFileNameOverrides.removeValue(forKey: segment.rangeKey)
        } else {
            splitFileNameOverrides[segment.rangeKey] = fileName
        }
        lastSplitOutputURLs = []
        errorMessage = nil
    }

    func splitFileNameValidationMessage(for segment: PDFSplitSegment) -> String? {
        let rawName = splitFileName(for: segment)
        guard let canonicalName = canonicalFileName(rawName) else {
            return BookletLocalization.string("File name cannot be empty.")
        }
        if canonicalName.contains("/") || canonicalName.contains(":") {
            return BookletLocalization.string("File name cannot contain / or :.")
        }

        let duplicateCount = splitSegments.reduce(into: 0) { count, candidate in
            guard let candidateName = canonicalSplitFileName(for: candidate) else { return }
            if candidateName.caseInsensitiveCompare(canonicalName) == .orderedSame {
                count += 1
            }
        }
        if duplicateCount > 1 {
            return BookletLocalization.string("Output file names must be unique.")
        }
        return nil
    }

    private func canonicalSplitFileName(for segment: PDFSplitSegment) -> String? {
        canonicalFileName(splitFileName(for: segment))
    }

    private func canonicalFileName(_ rawName: String) -> String? {
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.lowercased().hasSuffix(".pdf") {
            return String(trimmed.dropLast(4)) + ".pdf"
        }
        return trimmed + ".pdf"
    }

    // MARK: - Cancel

    /// Cancel the in-flight export (user-initiated).
    ///
    /// `isCancelling` stays true until the worker unwinds so the UI never
    /// pretends to be idle while a background task may still be writing.
    func cancel() {
        guard isRendering || isPreparingPreview else { return }
        isCancelling = true
        renderTask?.cancel()
        splitTask?.cancel()
        thumbnailTask?.cancel()
    }

    /// Cancel and forget any in-flight work without entering the
    /// user-visible `cancelling` state. Used when switching documents,
    /// clearing, or starting a newer job.
    private func cancelInternal() {
        renderTask?.cancel()
        renderTask = nil
        splitTask?.cancel()
        splitTask = nil
        thumbnailTask?.cancel()
        thumbnailTask = nil
        isCancelling = false
    }

    // MARK: - Thumbnails

    /// Re-render the preview thumbnails for the just-exported PDF in the
    /// background. Thumbnail failure must not invalidate an export that
    /// already succeeded; results are only applied while the same job is
    /// still active.
    private func startThumbnailPreparation(for outputURL: URL, jobID: UUID) {
        isPreparingPreview = true
        thumbnailTask = Task { [weak self] in
            guard let self else { return }
            let dir = BookletMakerRuntimeBridge.directoryURL
                ?? FileManager.default.temporaryDirectory
                    .appendingPathComponent("BookletMakerThumbnails", isDirectory: true)
            let thumbs = await self.thumbnailer.makeThumbnails(
                fromPDF: outputURL,
                count: 5,
                outputDirectory: dir
            )
            // A newer job (or document switch) owns the active ID; leave
            // every state transition to it. Otherwise clean up our own.
            guard self.activeExportJobID == jobID else {
                self.isPreparingPreview = false
                return
            }
            if self.isCancelling {
                self.isPreparingPreview = false
                self.isCancelling = false
                return
            }
            self.thumbnails = thumbs
            self.isPreparingPreview = false
        }
    }

    // MARK: - Finder helper

    /// Reveal a file in Finder. Silently no-ops if Finder can't be reached.
    /// macOS-only; iOS has no Finder.
    func revealInFinder(_ url: URL) {
        #if os(macOS)
        NSWorkspace.shared.activateFileViewerSelecting([url])
        #endif
    }

    private func releaseSecurityScope() {
        securityScopedURL?.stopAccessingSecurityScopedResource()
        securityScopedURL = nil
    }

    deinit {
        securityScopedURL?.stopAccessingSecurityScopedResource()
    }
}
