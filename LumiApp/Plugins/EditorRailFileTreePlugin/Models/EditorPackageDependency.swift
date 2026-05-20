import Foundation

enum EditorPackageDependencyKind: String, Codable, Sendable {
    case remote
    case local
}

enum EditorPackageDependencyStatus: Equatable, Sendable {
    case resolved
    case unresolved
    case missing(String)

    var displayText: String {
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

struct EditorPackageDependency: Identifiable, Equatable, Sendable {
    let identity: String
    let displayName: String
    let location: String
    let kind: EditorPackageDependencyKind
    let version: String?
    let branch: String?
    let revision: String?
    let status: EditorPackageDependencyStatus

    var id: String { identity }

    var subtitle: String {
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
