import EditorKernel
import Foundation

/// Pure rules for refreshing SourceKit after Xcode build context becomes ready.
enum EditorProjectContextLSPRefreshPolicy {
    static func shouldRefreshOpenDocument(
        isStructuredProject: Bool,
        contextStatus: EditorProjectContextStatus,
        hasOpenFile: Bool
    ) -> Bool {
        guard isStructuredProject, hasOpenFile else { return false }
        if case .available = contextStatus {
            return true
        }
        return false
    }
}
