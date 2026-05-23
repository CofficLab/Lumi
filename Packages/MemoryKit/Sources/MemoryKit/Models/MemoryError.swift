import Foundation

/// MemoryKit 错误类型
public enum MemoryError: LocalizedError, Sendable {
    case invalidFormat(String)
    case notFound(String)
    case fileSystemError(String)

    public var errorDescription: String? {
        switch self {
        case .invalidFormat(let msg): return "Invalid memory format: \(msg)"
        case .notFound(let msg): return "Memory not found: \(msg)"
        case .fileSystemError(let msg): return "File system error: \(msg)"
        }
    }
}
