import AppKit
import Foundation

/// Helper for writing HTTP exchange body data to disk.
enum HTTPExchangeBodyFileWriter {

    enum BodyKind: String, Sendable {
        case request = "request"
        case response = "response"
    }

    enum WriteError: LocalizedError {
        case noData
        case writeFailed(String)

        var errorDescription: String? {
            switch self {
            case .noData:
                return "No body data to save."
            case .writeFailed(let message):
                return message
            }
        }
    }

    /// Suggests a file name like "body-request-<shortID>.json".
    static func suggestedFileName(recordID: UUID, kind: BodyKind, mimeType: String?) -> String {
        let ext = fileExtension(for: mimeType)
        let short = String(recordID.uuidString.prefix(8))
        return "body-\(kind.rawValue)-\(short).\(ext)"
    }

    /// Maps MIME type to a file extension. Falls back to "bin" for unknown/binary types.
    static func fileExtension(for mimeType: String?) -> String {
        guard let mimeType else { return "bin" }
        switch mimeType.lowercased() {
        case _ where mimeType.contains("json"):         return "json"
        case _ where mimeType.contains("xml"):          return "xml"
        case _ where mimeType.contains("html"):         return "html"
        case _ where mimeType.contains("css"):          return "css"
        case _ where mimeType.contains("javascript"):   return "js"
        case _ where mimeType.contains("text/plain"):   return "txt"
        case _ where mimeType.contains("image/"):       return mimeType.contains("png") ? "png"
                                                             : mimeType.contains("gif") ? "gif"
                                                             : mimeType.contains("webp") ? "webp"
                                                             : "bin"
        case _ where mimeType.contains("pdf"):          return "pdf"
        case _ where mimeType.contains("zip"),
             _ where mimeType.contains("gzip"),
             _ where mimeType.contains("zstd"),
             _ where mimeType.contains("brotli"),
             _ where mimeType.contains("compressed"):  return "bin"
        default:                                        return "bin"
        }
    }

    /// Opens NSSavePanel, writes body data, returns the chosen URL on success,
    /// or throws on cancellation / failure.
    static func savePanelAndWrite(
        body: Data,
        recordID: UUID,
        kind: BodyKind,
        mimeType: String?
    ) throws -> URL {
        guard !body.isEmpty else { throw WriteError.noData }

        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedFileName(recordID: recordID, kind: kind, mimeType: mimeType)
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else {
            // User cancelled — not an error to surface.
            throw WriteError.writeFailed("Cancelled")
        }

        do {
            try body.write(to: url, options: .atomic)
            return url
        } catch {
            throw WriteError.writeFailed(error.localizedDescription)
        }
    }
}
