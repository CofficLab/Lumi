import Foundation

/// Skill 相关错误。
public enum SkillError: Error, Equatable, LocalizedError {
    case invalidContentPath(String)
    case invalidMetadata(String)

    public var errorDescription: String? {
        switch self {
        case .invalidContentPath(let detail):
            "Invalid content path: \(detail)"
        case .invalidMetadata(let detail):
            "Invalid metadata: \(detail)"
        }
    }
}

/// Skill 元数据模型（复刻旧版，表示 `.agent/skills/` 中一个 Skill）。
public struct SkillMetadata: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let title: String
    public let description: String
    public let triggers: [String]
    public let version: String
    public let contentPath: String
    public let modifiedAt: Date

    public init(
        id: String? = nil,
        name: String,
        title: String,
        description: String,
        triggers: [String] = [],
        version: String = "1.0.0",
        contentPath: String = "",
        modifiedAt: Date = Date()
    ) {
        self.id = id ?? name
        self.name = name
        self.title = title
        self.description = description
        self.triggers = triggers
        self.version = version
        self.contentPath = contentPath
        self.modifiedAt = modifiedAt
    }

    public func loadContent() throws -> String {
        guard !contentPath.isEmpty else {
            throw SkillError.invalidContentPath("Content path is empty for skill '\(name)'")
        }
        return try String(contentsOfFile: contentPath, encoding: .utf8)
    }
}

extension SkillMetadata: Codable {
    private enum CodingKeys: String, CodingKey {
        case name, title, description, triggers, version
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        triggers = try container.decodeIfPresent([String].self, forKey: .triggers) ?? []
        version = try container.decodeIfPresent(String.self, forKey: .version) ?? "1.0.0"
        id = name
        contentPath = ""
        modifiedAt = Date()
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(title, forKey: .title)
        try container.encode(description, forKey: .description)
        try container.encode(triggers, forKey: .triggers)
        try container.encode(version, forKey: .version)
    }
}
