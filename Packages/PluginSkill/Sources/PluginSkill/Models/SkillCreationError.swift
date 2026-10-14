import Foundation

/// Skill 写入错误。
public enum SkillCreationError: LocalizedError {
    case invalidName(String)
    case alreadyExists(String)
    case directoryUnavailable(String)

    public var errorDescription: String? {
        switch self {
        case .invalidName(let reason):
            return "Invalid skill name: \(reason)"
        case .alreadyExists(let path):
            return "Skill already exists: \(path)"
        case .directoryUnavailable(let path):
            return "Skills directory is not available: \(path)"
        }
    }
}
