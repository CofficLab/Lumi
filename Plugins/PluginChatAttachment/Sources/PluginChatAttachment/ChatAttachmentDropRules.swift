import Foundation

enum ChatAttachmentDropRules {
    static let imagePathExtensions: Set<String> = [
        "jpg", "jpeg", "png", "gif", "bmp", "tiff", "webp", "heic",
    ]

    static func isChatImageFileURL(_ url: URL) -> Bool {
        imagePathExtensions.contains(url.pathExtension.lowercased())
    }

    static func fileURL(fromDroppedString string: String) -> URL? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: trimmed), url.isFileURL {
            return url
        }
        guard trimmed.hasPrefix("/") else { return nil }
        return URL(fileURLWithPath: trimmed)
    }
}
