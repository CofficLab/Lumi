import Foundation

public enum EditorStatusMessageCatalog {
    public static func externalFileChangedOnDisk(fileName: String? = nil, isProjectFile: Bool = false) -> String {
        if isProjectFile {
            return "project.pbxproj changed on disk. Prefer the project version or keep the Lumi version before saving again."
        }
        if let fileName, !fileName.isEmpty {
            return "\(fileName) changed on disk. Reload or keep the editor version."
        }
        return "File changed on disk. Reload or keep the editor version."
    }

    public static func projectFileSaveConfirmation(fileName: String) -> String {
        "\(fileName) is an Xcode project file. Saving from Lumi can conflict with concurrent Xcode edits."
    }

    public static func saveFailed(_ detail: String? = nil) -> String {
        guard let detail, !detail.isEmpty else {
            return "Save failed. Check file permissions or path availability."
        }
        return "Save failed. \(detail)"
    }

    public static func fileNotFound() -> String {
        "Save failed. The file no longer exists on disk."
    }

    public static func formattingUnavailable(_ reason: String) -> String {
        "Formatting unavailable. \(reason)"
    }

    public static func languageFeatureUnavailable(operation: String, reason: String) -> String {
        "\(operation) unavailable. \(reason)"
    }
}
