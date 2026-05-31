import Foundation

enum ChatAttachmentDropRules {
    static let imagePathExtensions: Set<String> = [
        "jpg", "jpeg", "png", "gif", "bmp", "tiff", "webp", "heic",
    ]

    static func isChatImageFileURL(_ url: URL) -> Bool {
        imagePathExtensions.contains(url.pathExtension.lowercased())
    }

    static func fileURL(fromDroppedString string: String) -> URL? {
        fileURLs(fromDroppedString: string).first
    }

    static func fileURLs(fromDroppedString string: String) -> [URL] {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let lineURLs = trimmed
            .split(whereSeparator: \.isNewline)
            .compactMap { fileURL(fromSingleDroppedString: String($0)) }
        if !lineURLs.isEmpty {
            return lineURLs
        }

        return fileURL(fromSingleDroppedString: trimmed).map { [$0] } ?? []
    }

    private static func fileURL(fromSingleDroppedString string: String) -> URL? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: trimmed), url.isFileURL {
            return url
        }
        guard trimmed.hasPrefix("/") else { return nil }
        return URL(fileURLWithPath: trimmed)
    }
}
