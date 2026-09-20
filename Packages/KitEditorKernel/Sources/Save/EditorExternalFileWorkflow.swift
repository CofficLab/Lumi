import Foundation

public enum EditorExternalFileReloadDecision: Equatable, Sendable {
    case unchanged
    case registerConflict(content: String, modificationDate: Date)
    case applyExternalContent(content: String, modificationDate: Date)
}

public enum EditorExternalFileReloadPolicy {
    public static func reloadDecision(
        newContent: String,
        currentContent: String,
        currentModDate: Date,
        hasUnsavedChanges: Bool
    ) -> EditorExternalFileReloadDecision {
        guard newContent != currentContent else { return .unchanged }
        if hasUnsavedChanges {
            return .registerConflict(content: newContent, modificationDate: currentModDate)
        }
        return .applyExternalContent(content: newContent, modificationDate: currentModDate)
    }
}
