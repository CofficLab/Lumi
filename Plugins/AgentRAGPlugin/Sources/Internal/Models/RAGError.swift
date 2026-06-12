import Foundation

public enum RAGError: LocalizedError, Sendable {
    case notInitialized
    case invalidProjectPath
    case internalStateCorrupted
    case dbError(String)

    public var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "RAG service not initialized"
        case .invalidProjectPath:
            return "Invalid project path"
        case .internalStateCorrupted:
            return "RAG internal state corrupted"
        case let .dbError(message):
            return "RAG database error: \(message)"
        }
    }
}
