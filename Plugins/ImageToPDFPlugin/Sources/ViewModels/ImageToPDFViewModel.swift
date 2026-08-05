import AppKit
import Foundation
import SwiftUI
import UniformTypeIdentifiers

// MARK: - View Model

/// State container for the Image-to-PDF converter screen.
///
/// Owns the user's input image list, the per-file PDF output list, and
/// orchestrates the conversion and export pipelines. All mutations happen
/// on the main actor so SwiftUI bindings stay consistent.
@MainActor
final class ImageToPDFViewModel: ObservableObject {
    // MARK: - Inputs

    /// Images the user has dropped / picked but yet converted.
    @Published private(set) var inputImages: [ImageItem] = []

    /// PDFs produced by the most recent conversion run.
    @Published private(set) var outputItems: [PDFOutputItem] = []

    /// True while a `convertAll` is running.
    @Published private(set) var isConverting: Bool = false

    /// Human-readable message from the most recent failure, or nil.
    @Published private(set) var lastErrorMessage: String?

    // MARK: - Dependencies

    private let service: ImageToPDFService

    // MARK: Init

    init(service: ImageToPDFService = ImageToPDFService()) {
        self.service = service
    }

    // MARK: - Input Management

    /// Append files dragged into the drop zone. Filters to image files only
    /// and de-duplicates against the existing input list.
    ///
    /// - Parameter urls: URLs received from `NSItemProvider`.
    /// - Returns: Count of files actually added.
    @discardableResult
    func addImages(from urls: [URL]) -> Int {
        var added = 0
        for url in urls {
            guard ImageItem.isAccepted(url: url) else { continue }
            if inputImages.contains(where: { $0.url == url }) { continue }
            inputImages.append(ImageItem(url: url))
            added += 1
        }
        return added
    }

    /// Remove an image from the input list.
    func removeImage(_ item: ImageItem) {
        inputImages.removeAll { $0.id == item.id }
    }

    /// Open a file picker and add the selected image files.
    func pickImages() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image]

        if panel.runModal() == .OK {
            addImages(from: panel.urls)
        }
    }

    /// Clear every input image and every output PDF.
    func clearAll() {
        inputImages.removeAll()
        outputItems.removeAll()
        lastErrorMessage = nil
    }

    // MARK: - Conversion

    /// Convert every input image to a PDF in a temporary in-memory directory.
    ///
    /// PDFs are written to a staging directory inside the user's `Caches`
    /// folder and exposed via `outputItems` so the user can preview them
    /// before exporting to a final location.
    func convertAll() {
        guard !isConverting else { return }
        guard !inputImages.isEmpty else { return }

        let stagingDirectory = makeStagingDirectory()
        let images = inputImages
        outputItems = images.map { PDFOutputItem(source: $0) }
        isConverting = true
        lastErrorMessage = nil

        Task {
            var runningItems = outputItems

            for index in runningItems.indices {
                runningItems[index].status = .processing
                runningItems[index].progress = 0
                outputItems = runningItems

                let item = runningItems[index]
                let outputURL = stagingDirectory.appendingPathComponent(
                    item.source.suggestedPDFName
                )

                let stream = service.convert(source: item.source, to: outputURL)
                for await value in stream {
                    runningItems[index].progress = value
                    outputItems = runningItems
                }

                if FileManager.default.fileExists(atPath: outputURL.path) {
                    runningItems[index].status = .done(outputURL)
                    runningItems[index].progress = 1
                } else {
                    runningItems[index].status = .failed(
                        ImageToPDFLocalization.string("Unknown error")
                    )
                }
                outputItems = runningItems
            }

            isConverting = false

            let failureCount = outputItems.filter {
                if case .failed = $0.status { return true }
                return false
            }.count
            if failureCount > 0 {
                lastErrorMessage = String(
                    format: ImageToPDFLocalization.string("%l file(s) failed to convert"),
                    failureCount
                )
            }
        }
    }

    // MARK: - Export

    /// Export every successfully converted PDF to `directoryURL`.
    ///
    /// Returns the number of files actually written. Failed exports are
    /// surfaced through `lastErrorMessage`.
    @discardableResult
    func exportAll(to directoryURL: URL) -> Int {
        var written = 0
        var failed: [String] = []

        for index in outputItems.indices {
            guard case .done(let existingURL) = outputItems[index].status else {
                continue
            }

            let destination = directoryURL.appendingPathComponent(
                existingURL.lastPathComponent
            )

            do {
                try FileManager.default.createDirectory(
                    at: directoryURL,
                    withIntermediateDirectories: true
                )
                if FileManager.default.fileExists(atPath: destination.path) {
                    try FileManager.default.removeItem(at: destination)
                }
                try FileManager.default.copyItem(at: existingURL, to: destination)
                written += 1
            } catch {
                failed.append(existingURL.lastPathComponent)
            }
        }

        if !failed.isEmpty {
            lastErrorMessage = String(
                format: ImageToPDFLocalization.string("Could not export: %@"),
                failed.joined(separator: ", ")
            )
        } else {
            lastErrorMessage = nil
        }

        return written
    }

    /// Open a directory picker, then export every converted PDF there.
    func chooseDirectoryAndExport() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = ImageToPDFLocalization.string("Export")
        panel.message = ImageToPDFLocalization.string(
            "Choose a folder to export the PDFs into"
        )

        guard panel.runModal() == .OK, let directory = panel.url else { return }

        exportAll(to: directory)
    }

    /// Show the produced PDF in Finder.
    func revealInFinder(_ item: PDFOutputItem) {
        guard let url = item.status.outputURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    /// Open the produced PDF in Preview.app.
    func openInPreview(_ item: PDFOutputItem) {
        guard let url = item.status.outputURL else { return }
        NSWorkspace.shared.open(url)
    }

    /// Remove a single output item from the list (does not delete the PDF on disk).
    func removeOutput(_ item: PDFOutputItem) {
        outputItems.removeAll { $0.id == item.id }
    }

    // MARK: - Private

    /// Create (or reuse) a per-session staging directory.
    ///
    /// Prefers the directory provided by `ImageToPDFRuntimeBridge`, which
    /// `ImageToPDFPlugin.onBoot` populates from
    /// `kernel.storage?.pluginDataDirectory(for: "ImageToPDF")`. When the
    /// bridge is unavailable (e.g. in unit tests or boot-time UI), it
    /// falls back to a unique temporary folder so conversions still work.
    private func makeStagingDirectory() -> URL {
        let fm = FileManager.default
        let base = ImageToPDFRuntimeBridge.directoryURL
            ?? fm.temporaryDirectory.appendingPathComponent("ImageToPDFPlugin", isDirectory: true)

        try? fm.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }
}
