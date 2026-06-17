import Foundation

/// Tracks whether SourceKit compile database (`.compile`) is ready for the active scheme.
public enum XcodeSemanticIndexStatus: Equatable, Sendable {
    case notStarted
    case indexing
    case ready
    case failed(String)

    public var displayDescription: String {
        switch self {
        case .notStarted:
            return "Not Started"
        case .indexing:
            return "Indexing"
        case .ready:
            return "Ready"
        case .failed(let reason):
            return "Failed: \(reason)"
        }
    }
}
