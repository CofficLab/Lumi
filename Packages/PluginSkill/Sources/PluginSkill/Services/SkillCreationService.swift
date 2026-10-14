import Foundation
import ProviderSkill

/// 技能创建服务：在项目 `.agent/skills/<name>/` 下写入 `metadata.json` + `SKILL.md`。
///
/// 目录约定与 `SkillDirectoryLoader` 完全一致，因此写入后能被同一套扫描器
/// 立即识别，无需额外适配。
public actor SkillCreationService {
    public static let shared = SkillCreationService()

    private let fileManager = FileManager.default

    public init() {}

    /// 创建新技能。
    ///
    /// - Parameters:
    ///   - projectPath: 项目根目录绝对路径。
    ///   - name: 技能名（目录名），kebab-case。
    ///   - title: 展示标题。
    ///   - description: 一句话描述（注入 system prompt）。
    ///   - triggers: 触发词。
    ///   - content: `SKILL.md` 正文。为空时只写 frontmatter + 标题。
    /// - Returns: 写入后的技能元数据。
    public func createSkill(
        projectPath: String,
        name: String,
        title: String,
        description: String,
        triggers: [String] = [],
        content: String? = nil
    ) throws -> SkillMetadata {
        let name = Self.sanitize(name)
        guard !name.isEmpty else {
            throw SkillCreationError.invalidName("name is empty after normalization")
        }

        let directoryURL = URL(fileURLWithPath: projectPath)
            .appendingPathComponent(".agent/skills/\(name)", isDirectory: true)
        guard !fileManager.fileExists(atPath: directoryURL.path) else {
            throw SkillCreationError.alreadyExists(directoryURL.path)
        }

        do {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        } catch {
            throw SkillCreationError.directoryUnavailable(directoryURL.path)
        }

        let metadata = SkillMetadata(
            name: name,
            title: title.isEmpty ? name : title,
            description: description,
            triggers: triggers,
            version: "1.0.0"
        )
        try Self.writeMetadata(metadata, to: directoryURL)

        let body = Self.makeSkillMarkdown(metadata: metadata, content: content)
        let skillMDURL = directoryURL.appendingPathComponent("SKILL.md")
        try body.write(to: skillMDURL, atomically: true, encoding: .utf8)

        let modifiedAt = (try? skillMDURL.resourceValues(forKeys: [.contentModificationDateKey]))?
            .contentModificationDate ?? Date()
        return SkillMetadata(
            name: metadata.name,
            title: metadata.title,
            description: metadata.description,
            triggers: metadata.triggers,
            version: metadata.version,
            contentPath: skillMDURL.path,
            modifiedAt: modifiedAt
        )
    }

    // MARK: - 内部

    /// 技能目录名规范化：小写 + 空格/下划线转连字符，避免目录名出现空格。
    static func sanitize(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "[\\s_]+", with: "-", options: .regularExpression)
            .replacingOccurrences(of: "-{2,}", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    private static func writeMetadata(_ metadata: SkillMetadata, to directoryURL: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        // `SkillMetadata` 的 encode 只输出 name / title / description / triggers /
        // version，正好与扫描器解码的字段一致。
        let data = try encoder.encode(metadata)
        try data.write(to: directoryURL.appendingPathComponent("metadata.json"), options: .atomic)
    }

    /// 组装 `SKILL.md`：frontmatter + 标题 + 正文。
    ///
    /// 正文已带 frontmatter 或以一级标题开头时视为完整内容，避免重复包装。
    private static func makeSkillMarkdown(metadata: SkillMetadata, content: String?) -> String {
        let body = (content ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if body.hasPrefix("---") {
            return body + "\n"
        }

        var lines: [String] = ["---"]
        lines.append("name: \(metadata.name)")
        lines.append("description: \(metadata.description)")
        lines.append("---")
        lines.append("")
        lines.append("# \(metadata.title)")
        if !body.isEmpty {
            if body.hasPrefix("# ") {
                lines.append(body)
            } else {
                lines.append("")
                lines.append(body)
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }
}
