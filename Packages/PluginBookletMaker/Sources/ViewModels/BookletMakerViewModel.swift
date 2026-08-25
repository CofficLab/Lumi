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

    /// User-defined output names, keyed by the exact page range they describe.
    @Published private var splitFileNameOverrides: [String: String] = [:]

    /// Render progress in 0.0 ... 1.0. 0 when idle.
    @Published private(set) var progress: Double = 0

    /// True while a render is in flight.
    @Published private(set) var isRendering: Bool = false

    /// True while the exported PDF is being prepared for preview.
    @Published private(set) var isPreparingPreview: Bool = false

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
        cancel()
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
        cancel()
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
    func export(to outputURL: URL) async {
        let inputURL = currentDocument.url

        cancel()
        isRendering = true
        isPreparingPreview = false
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
            isPreparingPreview = true
            await refreshThumbnails(for: outputURL)
            isPreparingPreview = false
        }
    }

    /// Export all currently planned page ranges into `outputDirectory`.
    func exportSplit(to outputDirectory: URL) async {
        guard canExportSplit else { return }
        let outputs = splitOutputs
        let sourceURL = currentDocument.url

        cancel()
        isRendering = true
        isPreparingPreview = false
        progress = 0
        lastOutputURL = nil
        lastSplitOutputURLs = []
        errorMessage = nil

        let splitter = self.splitter
        let progressStream = AsyncStream<Double>.makeStream()
        let progressTask = Task { [weak self] in
            for await value in progressStream.stream {
                guard let self else { return }
                self.progress = value
            }
        }
        let task = Task {
            try await splitter.split(
                sourceURL: sourceURL,
                outputDirectory: outputDirectory,
                outputs: outputs,
                progress: { progressStream.continuation.yield($0) }
            )
        }
        splitTask = task

        do {
            let urls = try await task.value
            if !Task.isCancelled {
                lastSplitOutputURLs = urls
                progress = 1
                Self.logger.info("\(Self.t)Split export complete: \(urls.count) files")
            }
        } catch is CancellationError {
            // Cancellation is an expected result when switching documents/tools.
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? error.localizedDescription
            Self.logger.error("\(Self.t)Split export failed: \(self.errorMessage ?? "unknown error")")
        }
        progressStream.continuation.finish()
        await progressTask.value
        splitTask = nil
        isRendering = false
        isPreparingPreview = false
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

    /// Cancel the current render, if any.
    func cancel() {
        renderTask?.cancel()
        renderTask = nil
        splitTask?.cancel()
        splitTask = nil
        isRendering = false
        isPreparingPreview = false
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
