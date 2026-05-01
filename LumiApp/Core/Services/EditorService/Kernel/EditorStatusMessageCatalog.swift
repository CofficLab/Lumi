import Foundation

enum EditorStatusMessageCatalog {
    static func externalFileChangedOnDisk(fileName: String? = nil, isProjectFile: Bool = false) -> String {
        if isProjectFile {
            return "project.pbxproj changed on disk. Prefer the project version or keep the Lumi version before saving again."
        }
        if let fileName, !fileName.isEmpty {
            return "\(fileName) changed on disk. Reload or keep the editor version."
        }
        return "File changed on disk. Reload or keep the editor version."
    }

    static func projectFileSaveConfirmation(fileName: String) -> String {
        "\(fileName) is an Xcode project file. Saving from Lumi can conflict with concurrent Xcode edits."
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
