import Foundation
import PDFKit

// MARK: - Splitter Protocol

/// Splitting contract used by the view model.
///
/// The protocol exists so tests can inject a splitter whose completion
/// order is controlled, which is required to verify that a late old job
/// cannot overwrite a newer job's state.
protocol PDFSplitting: Sendable {
    /// Write one PDF per planned range and return the produced URLs.
    ///
    /// - Parameters:
    ///   - sourceURL: the input PDF.
    ///   - outputDirectory: existing or to-be-created directory for outputs.
    ///   - outputs: the planned page ranges and file names.
    ///   - progress: called with values in `0.0 ... 1.0`. May be called from
    ///     a background context.
    /// - Returns: the URLs of the files written, in plan order.
    /// - Throws: `CancellationError` if cancelled, or
    ///   `PDFSplitter.SplitError` describing the failure.
    func split(sourceURL: URL,
               outputDirectory: URL,
               outputs: [PDFSplitOutput],
               progress: @escaping @Sendable (Double) -> Void) async throws -> [URL]
}

// MARK: - PDF Splitter

/// Writes page ranges from one source PDF into separate vector PDF files.
final class PDFSplitter: PDFSplitting, @unchecked Sendable {
    enum SplitError: LocalizedError {
        case sourceUnreadable(URL)
        case outputContextFailed(URL)
        case outputAlreadyExists(URL)
        case writeFailed(URL)

        var errorDescription: String? {
            switch self {
            case .sourceUnreadable(let url):
                BookletLocalization.string("Could not open source PDF: %@", url.lastPathComponent)
            case .outputContextFailed(let url):
                BookletLocalization.string("Could not create output PDF context: %@", url.lastPathComponent)
            case .outputAlreadyExists(let url):
                BookletLocalization.string("Output file already exists: %@", url.lastPathComponent)
            case .writeFailed(let url):
                BookletLocalization.string("Could not write output PDF: %@", url.lastPathComponent)
            }
        }
    }

    func split(sourceURL: URL,
               outputDirectory: URL,
               outputs: [PDFSplitOutput],
               progress: @escaping @Sendable (Double) -> Void = { _ in }) async throws -> [URL] {
        try Task.checkCancellation()

        let worker = Task.detached(priority: .userInitiated) {
            try Self.runSplit(
                sourceURL: sourceURL,
                outputDirectory: outputDirectory,
                outputs: outputs,
                progress: progress
            )
        }
        return try await withTaskCancellationHandler {
            try await worker.value
        } onCancel: {
            worker.cancel()
        }
    }

    private static func runSplit(sourceURL: URL,
                                 outputDirectory: URL,
                                 outputs: [PDFSplitOutput],
                                 progress: @Sendable (Double) -> Void) throws -> [URL] {
        progress(0.05)
        guard let source = PDFDocument(url: sourceURL),
              !source.isLocked,
              source.pageCount > 0 else {
            throw SplitError.sourceUnreadable(sourceURL)
        }

        try FileManager.default.createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: true
        )

        let outputURLs = outputs.map {
            outputDirectory.appendingPathComponent($0.fileName)
        }
        if let existing = outputURLs.first(where: {
            FileManager.default.fileExists(atPath: $0.path)
        }) {
            throw SplitError.outputAlreadyExists(existing)
        }

        var completed: [URL] = []
        do {
            for (index, pair) in zip(outputs, outputURLs).enumerated() {
                try Task.checkCancellation()
                let (plannedOutput, outputURL) = pair
                let output = PDFDocument()

                for pageNumber in plannedOutput.segment.startPage ... plannedOutput.segment.endPage {
                    try Task.checkCancellation()
                    guard let page = source.page(at: pageNumber - 1)?.copy() as? PDFPage else {
                        throw SplitError.sourceUnreadable(sourceURL)
                    }
                    output.insert(page, at: output.pageCount)
                }

                guard let data = output.dataRepresentation() else {
                    throw SplitError.outputContextFailed(outputURL)
                }
                do {
                    try data.write(to: outputURL, options: .atomic)
                } catch {
                    throw SplitError.writeFailed(outputURL)
                }
                completed.append(outputURL)
                progress(0.05 + 0.90 * Double(index + 1) / Double(max(outputs.count, 1)))
            }
            progress(1)
            return completed
        } catch {
            // Remove every partially written file so a cancelled or failed
            // job never leaves half of its output behind.
            for url in completed {
                try? FileManager.default.removeItem(at: url)
            }
            throw error
        }
    }
}
