import Foundation
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Image Item

/// Represents an image file the user has dropped into the converter.
struct ImageItem: Identifiable, Hashable {
    let id: UUID
    let url: URL
    let fileSize: UInt64
    let addedAt: Date

    init(url: URL, fileSize: UInt64? = nil) {
        self.id = UUID()
        self.url = url
        self.addedAt = Date()
        if let fileSize {
            self.fileSize = fileSize
        } else {
            let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
            self.fileSize = (attrs?[.size] as? UInt64) ?? 0
        }
    }

    /// Display name shown in the UI.
    var lastPathComponent: String {
        url.lastPathComponent
    }

    /// Suggested output file name (same stem, `.pdf` extension).
    var suggestedPDFName: String {
        url.deletingPathExtension().lastPathComponent + ".pdf"
    }

    /// Whether the file looks like an image we can convert.
    static func isAccepted(url: URL) -> Bool {
        guard let type = UTType(filenameExtension: url.pathExtension.lowercased()) else {
            return false
        }
        return type.conforms(to: .image)
    }
}