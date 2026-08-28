import CoreGraphics
import Foundation
import os
import KitSuperLog

// MARK: - PDF Inspector

/// Lightweight wrapper around `CGPDFDocument` that extracts just the
/// information the Booklet Maker needs (page count, first-page size,
/// encryption state).
///
/// The service is stateless and uses `Task.detached` so the UI thread
/// is never blocked while we read multi-megabyte PDFs.
final class PDFInspector: SuperLog, @unchecked Sendable {

    // MARK: - Identity

    nonisolated static let emoji = "📖"
    nonisolated static let verbose: Bool = false
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.booklet-maker.inspector"
    )

    init() {}

    // MARK: - Errors

    enum InspectionError: LocalizedError {
        case fileNotFound(URL)
        case unreadablePDF(URL)
        case zeroPagePDF(URL)
        case encryptedPDF(URL)

        var errorDescription: String? {
            switch self {
            case .fileNotFound(let url):
                return BookletLocalization.string("File not found: %@", url.lastPathComponent)
            case .unreadablePDF(let url):
                return BookletLocalization.string("Could not read PDF: %@", url.lastPathComponent)
            case .zeroPagePDF(let url):
                return BookletLocalization.string("PDF has no pages: %@", url.lastPathComponent)
            case .encryptedPDF(let url):
                return BookletLocalization.string("PDF is password-protected: %@", url.lastPathComponent)
            }
        }
    }

    // MARK: - Result

    struct PDFInfo: Equatable, Sendable {
        let pageCount: Int
        let firstPageSize: CGSize   // in points
    }

    // MARK: - API

    /// Inspect `url` and return its basic information.
    func inspect(_ url: URL) async throws -> PDFInfo {
        try await Task.detached(priority: .userInitiated) {
            try Self.runInspection(url: url)
        }.value
    }

    // MARK: - Pipeline

    private static func runInspection(url: URL) throws -> PDFInfo {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw InspectionError.fileNotFound(url)
        }
        guard let doc = CGPDFDocument(url as CFURL) else {
            throw InspectionError.unreadablePDF(url)
        }
        if doc.isEncrypted {
            throw InspectionError.encryptedPDF(url)
        }
        let count = doc.numberOfPages
        guard count > 0, let page = doc.page(at: 1) else {
            throw InspectionError.zeroPagePDF(url)
        }
        // Preview.app presents the visible page defined by CropBox. A number
        // of textbook PDFs retain a landscape two-page spread as MediaBox and
        // expose each portrait page through CropBox; using MediaBox here makes
        // the preview container and the rendered page disagree on aspect.
        let box = page.getBoxRect(.cropBox)
        return PDFInfo(pageCount: count, firstPageSize: box.size)
    }
}
