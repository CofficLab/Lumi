import Foundation

/// Memory Plugin 工具错误
public enum MemoryToolError: LocalizedError {
    case missingArgument(String)
    case invalidArgument(String)

    public var errorDescription: String? {
        switch self {
        case .missingArgument(let name): return "Missing required argument: '\(name)'"
        case .invalidArgument(let msg): return "Invalid argument: \(msg)"
        }
    }
}
