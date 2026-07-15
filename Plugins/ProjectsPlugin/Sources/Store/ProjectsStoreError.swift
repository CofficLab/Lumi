import Foundation

public enum ProjectsStoreError: LocalizedError {
    case pathDoesNotExist(String)
    case pathIsNotDirectory(String)

    public var errorDescription: String? {
        switch self {
        case let .pathDoesNotExist(path):
            "Path does not exist: \(path)"
        case let .pathIsNotDirectory(path):
            "Path is not a directory: \(path)"
        }
    }
}
