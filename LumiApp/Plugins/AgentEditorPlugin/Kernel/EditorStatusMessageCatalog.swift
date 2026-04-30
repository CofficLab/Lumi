import Foundation

enum EditorStatusMessageCatalog {
    static func externalFileChangedOnDisk() -> String {
        "File changed on disk. Reload or keep the editor version."
    }

    static func saveFailed(_ detail: String? = nil) -> String {
        guard let detail, !detail.isEmpty else {
            return "Save failed. Check file permissions or path availability."
        }
        return "Save failed. \(detail)"
    }

    static func fileNotFound() -> String {
        "Save failed. The file no longer exists on disk."
    }

    static func formattingUnavailable(_ reason: String) -> String {
        "Formatting unavailable. \(reason)"
    }

    static func languageFeatureUnavailable(operation: String, reason: String) -> String {
        "\(operation) unavailable. \(reason)"
    }
}
