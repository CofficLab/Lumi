import Foundation
import PDFKit

/// Writes page ranges from one source PDF into separate vector PDF files.
final class PDFSplitter: @unchecked Sendable {
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
               outputs: [PDFSplitOutput]) async throws -> [URL] {
        try await Task.detached(priority: .userInitiated) {
            try Self.runSplit(
                sourceURL: sourceURL,
                outputDirectory: outputDirectory,
                outputs: outputs
            )
        }.value
    }

    private static func runSplit(sourceURL: URL,
                                 outputDirectory: URL,
                                 outputs: [PDFSplitOutput]) throws -> [URL] {
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
            for (plannedOutput, outputURL) in zip(outputs, outputURLs) {
                let output = PDFDocument()

                for pageNumber in plannedOutput.segment.startPage ... plannedOutput.segment.endPage {
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
            }
            return completed
        } catch {
            for url in completed {
                try? FileManager.default.removeItem(at: url)
            }
            throw error
        }
    }
}
