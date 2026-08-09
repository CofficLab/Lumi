import AppKit
import Combine
import CoreGraphics
import Foundation
import os
import SuperLogKit
import SwiftUI

// MARK: - Booklet Maker View Model

/// Drives the Booklet Maker workspace view.
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
    private let thumbnailer = BookletThumbnailer()

    private var renderTask: Task<Void, Never>?

    // MARK: - Published state

    /// Currently selected input PDF, if any.
    @Published private(set) var inputURL: URL?

    /// Page count and first-page size of the input.
    @Published private(set) var inputInfo: PDFInspector.PDFInfo?

    /// Current imposition settings.
    @Published var settings: BookletSettings = .init()

    /// Render progress in 0.0 ... 1.0. 0 when idle.
    @Published private(set) var progress: Double = 0

    /// True while a render is in flight.
    @Published private(set) var isRendering: Bool = false

    /// URL of the most recent successful export.
    @Published private(set) var lastOutputURL: URL?

    /// Generated preview thumbnails.
    @Published private(set) var thumbnails: [BookletThumbnailer.Thumbnail] = []

    /// Last error message, if any.
    @Published var errorMessage: String?

    // MARK: - Init

    init() {}

    // MARK: - Derived

    /// Physical pieces of paper required by the current layout.
    var expectedSheetCount: Int {
        guard let info = inputInfo else { return 0 }
        return BookletLayoutEngine.buildPhysicalSheets(
            inputPageCount: info.pageCount,
            settings: settings
        ).count
    }

    /// PDF pages / print sides produced by the current layout.
    var expectedOutputPageCount: Int {
        guard let info = inputInfo else { return 0 }
        return BookletLayoutEngine.buildOutputSides(
            inputPageCount: info.pageCount,
            settings: settings
        ).count
    }

    var hasInput: Bool { inputURL != nil }
    var canExport: Bool { inputURL != nil && !isRendering }

    // MARK: - Input handling

    /// Load a PDF. Cancels any in-flight work, then inspects the file.
    func loadPDF(_ url: URL) async {
        cancel()
        errorMessage = nil
        progress = 0
        thumbnails = []
        lastOutputURL = nil
        inputURL = url
        inputInfo = nil

        do {
            let info = try await inspector.inspect(url)
            inputInfo = info
            Self.logger.info("\(Self.t)Loaded \(url.lastPathComponent) — \(info.pageCount) pages")
        } catch {
            let message = (error as? LocalizedError)?.errorDescription
                ?? error.localizedDescription
            errorMessage = message
            inputURL = nil
            inputInfo = nil
            Self.logger.error("\(Self.t)Inspection failed: \(message)")
        }
    }

    /// Clear the current input.
    func clear() {
        cancel()
        inputURL = nil
        inputInfo = nil
        progress = 0
        thumbnails = []
        lastOutputURL = nil
        errorMessage = nil
    }

    // MARK: - Export

    /// Render the impositioned PDF to `outputURL`.
    func export(to outputURL: URL) async {
        guard let inputURL, let inputInfo else { return }

        cancel()
        isRendering = true
        progress = 0
        thumbnails = []
        lastOutputURL = nil
        errorMessage = nil

        let settings = self.settings
        let stream = renderer.render(sourceURL: inputURL,
                                     outputURL: outputURL,
                                     settings: settings)
        let totalPages = inputInfo.pageCount

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
            _ = totalPages // silence unused if needed in future
        }

        // Wait for the task to finish before kicking off thumbnails.
        await renderTask?.value
        if let _ = lastOutputURL {
            await refreshThumbnails(for: outputURL)
        }
    }

    /// Cancel the current render, if any.
    func cancel() {
        renderTask?.cancel()
        renderTask = nil
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
}
