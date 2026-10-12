import Foundation

public enum EditorPanelDataPolicy {
    public static func normalizedReferenceSelection(
        selected: EditorReferenceResult?,
        availableResults: [EditorReferenceResult]
    ) -> EditorReferenceResult? {
        guard let selected else { return nil }
        return availableResults.contains(selected) ? selected : nil
    }

    public static func normalizedWorkspaceSearchState(
        collapsedFilePaths: Set<String>,
        selectedMatchID: String?,
        results: [EditorWorkspaceSearchFileResult]
    ) -> (collapsedFilePaths: Set<String>, selectedMatchID: String?) {
        let visiblePaths = Set(results.map(\.path))
        let normalizedCollapsedPaths = collapsedFilePaths.intersection(visiblePaths)
        let visibleMatchIDs = Set(results.flatMap { $0.matches.map(\.id) })
        let normalizedSelectedMatchID: String?
        if let selectedMatchID, visibleMatchIDs.contains(selectedMatchID) {
            normalizedSelectedMatchID = selectedMatchID
        } else {
            normalizedSelectedMatchID = nil
        }
        return (normalizedCollapsedPaths, normalizedSelectedMatchID)
    }

    public static func toggledCollapsedFilePath(
        _ path: String,
        in collapsedFilePaths: Set<String>
    ) -> Set<String> {
        var collapsedFilePaths = collapsedFilePaths
        if collapsedFilePaths.contains(path) {
            collapsedFilePaths.remove(path)
        } else {
            collapsedFilePaths.insert(path)
        }
        return collapsedFilePaths
    }
}
