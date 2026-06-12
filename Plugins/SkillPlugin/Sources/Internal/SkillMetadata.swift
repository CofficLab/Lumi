import Foundation

/// Skill 相关错误
public enum SkillError: Error, Equatable, LocalizedError {
    /// 内容路径无效
    case invalidContentPath(String)
    /// 元数据验证失败
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

/// Skill 元数据模型
///
/// 表示 `.agent/skills/` 目录中一个 Skill 的元数据信息。
/// 元数据来自 `metadata.json` 文件，用于 Prompt 注入和 UI 展示。
public struct SkillMetadata: Identifiable, Equatable, Sendable {
    /// 使用 name 作为稳定标识符
    public let id: String

    /// Skill 唯一标识，如 "swiftui-expert"
    public let name: String

    /// 显示标题，如 "SwiftUI Expert"
    public let title: String

    /// 一句话描述
    public let description: String

    /// 触发关键词（预留，用于后续智能匹配）
    public let triggers: [String]

    /// 版本号
    public let version: String

    /// SKILL.md 文件路径
    public let contentPath: String

    /// 修改时间
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

    /// 加载完整 Skill 内容
    ///
    /// 当 `contentPath` 为空或文件不存在时抛出错误。
    public func loadContent() throws -> String {
        guard !contentPath.isEmpty else {
            throw SkillError.invalidContentPath("Content path is empty for skill '\(name)'")
        }

        var encoding = String.Encoding.utf8
        return try String(contentsOfFile: contentPath, usedEncoding: &encoding)
    }
}

// MARK: - Codable

extension SkillMetadata: Codable {
    /// JSON 编解码的键
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
