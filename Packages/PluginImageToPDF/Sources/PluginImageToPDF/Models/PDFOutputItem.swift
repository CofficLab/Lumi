import Foundation
import SwiftUI

// MARK: - Output Status

/// Lifecycle states for a converted PDF item.
enum PDFOutputStatus: Equatable {
    case pending
    case processing
    case done(URL)
    case failed(String)

    var isTerminal: Bool {
        switch self {
        case .done, .failed: return true
        case .pending, .processing: return false
        }
    }

    var outputURL: URL? {
        if case .done(let url) = self { return url }
        return nil
    }
}

// MARK: - PDF Output Item

/// Represents one PDF produced (or pending) for an input image.
struct PDFOutputItem: Identifiable, Equatable {
    let id: UUID
    let source: ImageItem
    var status: PDFOutputStatus
    var progress: Double

    init(source: ImageItem) {
        self.id = UUID()
        self.source = source
        self.status = .pending
        self.progress = 0
    }

    /// Label shown in the UI based on status.
    var displayStatus: String {
        switch status {
        case .pending:
            return ImageToPDFLocalization.string("Pending")
        case .processing:
            return ImageToPDFLocalization.string("Processing…")
        case .done:
            return ImageToPDFLocalization.string("Done")
        case .failed:
            return ImageToPDFLocalization.string("Failed")
        }
    }
}