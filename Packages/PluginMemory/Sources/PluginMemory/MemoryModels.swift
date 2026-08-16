import Foundation

/// 记忆类型（与 Claude Code memdir 一致）。
public enum MemoryType: String, Codable, CaseIterable, Sendable {
    case user
    case feedback
    case project
    case reference

    public var displayName: String {
        switch self {
        case .user: return "User"
        case .feedback: return "Feedback"
        case .project: return "Project"
        case .reference: return "Reference"
        }
    }
}

/// 记忆作用域。
public enum MemoryScope: String, Codable, Sendable {
    case global
    case project
}

/// 记忆条目（对应磁盘上一条 Markdown 记忆文件）。
public struct MemoryItem: Codable, Identifiable, Sendable {
    public let id: String
    public let type: MemoryType
    public let name: String
    public let description: String
    public let content: String
    public let createdAt: Date
    public let updatedAt: Date
    public let filePath: String

    public init(
        id: String,
        type: MemoryType,
        name: String,
        description: String,
        content: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        filePath: String
    ) {
        self.id = id
        self.type = type
        self.name = name
        self.description = description
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.filePath = filePath
    }

    public func formattedSummary() -> String {
        "[\(type.rawValue)] \(name) — \(description)"
    }

    public func formattedContent(staleThresholdDays: Int) -> String {
        var parts: [String] = []
        parts.append("**\(formattedSummary())**")
        parts.append("")
        parts.append(content)
        return parts.joined(separator: "\n")
    }
}

/// 记忆相关错误。
public enum MemoryError: Error, LocalizedError, Equatable {
    case invalidID(String)
    case storageUnavailable(String)

    public var errorDescription: String? {
        switch self {
        case .invalidID(let detail):
            "Invalid memory id: \(detail)"
        case .storageUnavailable(let detail):
            "Memory storage unavailable: \(detail)"
        }
    }
}
