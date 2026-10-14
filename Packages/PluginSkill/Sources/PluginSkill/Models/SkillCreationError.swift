import Foundation

/// Skill 读写错误。
public enum SkillCreationError: LocalizedError, Equatable {
    case invalidName(String)
    case invalidFile(String)
    case alreadyExists(String)
    case notFound(String)
    case directoryUnavailable(String)

    public var errorDescription: String? {
        switch self {
        case .invalidName(let reason):
            return "Invalid skill name: \(reason)"
        case .invalidFile(let path):
            return "Skill metadata is missing or unreadable: \(path)"
        case .alreadyExists(let path):
            return "Skill already exists: \(path)"
        case .notFound(let path):
            return "Skill not found: \(path)"
        case .directoryUnavailable(let path):
            return "Skills directory is not available: \(path)"
        }
    }
}
