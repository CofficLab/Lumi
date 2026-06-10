import Foundation

public enum EditorPackageDependencyKind: String, Codable, Sendable {
    case remote
    case local
}

public enum EditorPackageDependencyStatus: Equatable, Sendable {
    case resolved
    case unresolved
    case missing(String)

    public var displayText: String {
        switch self {
        case .resolved:
            return "Resolved"
        case .unresolved:
            return "Unresolved"
        case .missing(let detail):
            return detail
        }
    }
}

public struct EditorPackageDependency: Identifiable, Equatable, Sendable {
    public let identity: String
    public let displayName: String
    public let location: String
    public let kind: EditorPackageDependencyKind
    public let version: String?
    public let branch: String?
    public let revision: String?
    public let status: EditorPackageDependencyStatus

    public var id: String { identity }

    public var subtitle: String {
        if let version, !version.isEmpty {
            return version
        }
        if let branch, !branch.isEmpty {
            return branch
        }
        if let revision, !revision.isEmpty {
            return String(revision.prefix(8))
        }
        return kind == .local ? location : status.displayText
    }
}
