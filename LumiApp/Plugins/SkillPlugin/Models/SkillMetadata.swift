import Foundation

/// Skill 元数据模型
///
/// 表示 `.agent/skills/` 目录中一个 Skill 的元数据信息。
/// 元数据来自 `metadata.json` 文件，用于 Prompt 注入和 UI 展示。
struct SkillMetadata: Identifiable, Equatable, Sendable {
    /// 使用 name 作为稳定标识符
    let id: String

    /// Skill 唯一标识，如 "swiftui-expert"
    let name: String

    /// 显示标题，如 "SwiftUI Expert"
    let title: String

    /// 一句话描述
    let description: String

    /// 触发关键词（预留，用于后续智能匹配）
    let triggers: [String]

    /// 版本号
    let version: String

    /// SKILL.md 文件路径
    let contentPath: String

    /// 修改时间
    let modifiedAt: Date
}

// MARK: - Codable

extension SkillMetadata: Codable {
    /// JSON 编解码的键
    private enum CodingKeys: String, CodingKey {
        case name, title, description, triggers, version
    }

    init(from decoder: Decoder) throws {
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

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(title, forKey: .title)
        try container.encode(description, forKey: .description)
        try container.encode(triggers, forKey: .triggers)
        try container.encode(version, forKey: .version)
    }
}
