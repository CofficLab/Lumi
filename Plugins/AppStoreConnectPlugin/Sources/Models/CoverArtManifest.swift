import Foundation

struct CoverArtManifest: Codable, Equatable, Identifiable, Sendable {
    let id: String
    var title: String
    var displayType: String
    var width: Int
    var height: Int
    var createdAt: Date
    var updatedAt: Date

    var htmlFileName: String { CoverArtDocumentStore.indexHTMLFileName }
    var manifestFileName: String { CoverArtDocumentStore.manifestFileName }
}

struct CoverArtDocument: Equatable, Sendable {
    let manifest: CoverArtManifest
    let html: String
    let directoryURL: URL

    var indexHTMLURL: URL {
        directoryURL.appendingPathComponent(CoverArtDocumentStore.indexHTMLFileName)
    }

    var assetsDirectoryURL: URL {
        directoryURL.appendingPathComponent(CoverArtDocumentStore.assetsDirectoryName, isDirectory: true)
    }
}

enum CoverArtSlugValidator {
    private static let slugRegex = try? NSRegularExpression(pattern: "^[a-z0-9]+(?:-[a-z0-9]+)*$")

    static func normalize(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty,
              let slugRegex,
              slugRegex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) != nil else {
            return nil
        }
        return trimmed
    }

    static func slug(from title: String, fallback: String = "cover-art") -> String {
        let parts = title
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        let candidate = parts.joined(separator: "-")
        return normalize(candidate) ?? fallback
    }
}
