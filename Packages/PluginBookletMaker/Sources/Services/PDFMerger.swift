import Foundation
import PDFKit

// MARK: - Merger Protocol

protocol PDFMerging: Sendable {
    /// Merge source PDFs in the supplied order into one new PDF.
    func merge(
        sourceURLs: [URL],
        outputURL: URL,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> URL
}

// MARK: - PDF Merger

/// Concatenates PDF pages without rasterising them.
final class PDFMerger: PDFMerging, @unchecked Sendable {
    enum MergeError: LocalizedError {
        case tooFewSources
        case sourceUnreadable(URL)
        case outputContextFailed(URL)
        case writeFailed(URL)

        var errorDescription: String? {
            switch self {
            case .tooFewSources:
                BookletLocalization.string("Select at least two PDF files to merge.")
            case .sourceUnreadable(let url):
                BookletLocalization.string("Could not open source PDF: %@", url.lastPathComponent)
            case .outputContextFailed(let url):
                BookletLocalization.string("Could not create output PDF: %@", url.lastPathComponent)
            case .writeFailed(let url):
                BookletLocalization.string("Could not write output PDF: %@", url.lastPathComponent)
            }
        }
    }

    func merge(
        sourceURLs: [URL],
        outputURL: URL,
        progress: @escaping @Sendable (Double) -> Void = { _ in }
    ) async throws -> URL {
        guard sourceURLs.count >= 2 else { throw MergeError.tooFewSources }
        try Task.checkCancellation()

        let worker = Task.detached(priority: .userInitiated) {
            try Self.runMerge(
                sourceURLs: sourceURLs,
                outputURL: outputURL,
                progress: progress
            )
        }
        return try await withTaskCancellationHandler {
            try await worker.value
        } onCancel: {
            worker.cancel()
        }
    }

    private static func runMerge(
        sourceURLs: [URL],
        outputURL: URL,
        progress: @Sendable (Double) -> Void
    ) throws -> URL {
        let output = PDFDocument()
        let total = max(sourceURLs.count, 1)

        for (sourceIndex, sourceURL) in sourceURLs.enumerated() {
            try Task.checkCancellation()
            guard let source = PDFDocument(url: sourceURL),
                  !source.isLocked,
                  source.pageCount > 0 else {
                throw MergeError.sourceUnreadable(sourceURL)
            }

            for pageIndex in 0 ..< source.pageCount {
                try Task.checkCancellation()
                guard let page = source.page(at: pageIndex)?.copy() as? PDFPage else {
                    throw MergeError.sourceUnreadable(sourceURL)
                }
                output.insert(page, at: output.pageCount)
            }
            progress(Double(sourceIndex + 1) / Double(total) * 0.9)
        }

        guard let data = output.dataRepresentation() else {
            throw MergeError.outputContextFailed(outputURL)
        }
        do {
            try data.write(to: outputURL, options: .atomic)
        } catch {
            throw MergeError.writeFailed(outputURL)
        }
        progress(1)
        return outputURL
    }
}
