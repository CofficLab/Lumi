import Foundation
import KitAgentTool
import ProviderSkill

/// 技能读写服务：`.lumi/skills/<name>/` 下的 `metadata.json` + `SKILL.md`。
///
/// 目录约定与 `SkillDirectoryLoader` 完全一致，因此写入后能被同一套扫描器
/// 立即识别，无需额外适配。所有 skill 工具（list / create / read / update /
/// delete）都经由本服务落盘，避免每个工具各写一份文件系统逻辑。
///
/// **写入**只落 `.lumi/skills/`；**读取**兼容历史目录 `.agent/skills/`：
/// - 新建技能一律写入 `.lumi/skills/<name>/`；
/// - 更新 / 删除历史目录中的技能时，在其**原位**操作，不做隐式迁移。
public actor SkillCreationService {
    public static let shared = SkillCreationService()

    private let fileManager = FileManager.default

    public init() {}

    // MARK: - Create

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

        // 同名技能若已存在（无论在 `.lumi/skills` 还是历史目录 `.agent/skills`），
        // 一律拒绝创建，避免两个目录出现同名技能导致读取歧义。
        if let existing = locateSkillDirectory(projectPath: projectPath, name: name) {
            throw SkillCreationError.alreadyExists(existing.path)
        }

        // 新建技能一律写入 `.lumi/skills/<name>/`。
        let directoryURL = try makeWriteDirectory(projectPath: projectPath, name: name)

        let metadata = SkillMetadata(
            name: name,
            title: title.isEmpty ? name : title,
            description: description,
            triggers: triggers,
            version: "1.0.0"
        )
        try Self.writeMetadata(metadata, to: directoryURL)
        try Self.writeBody(Self.makeSkillMarkdown(metadata: metadata, content: content), to: directoryURL)
        // 刚写完的文件必定可读；读失败说明写入未落盘，直接用内存中的元数据兜底。
        return Self.loadMetadata(name: name, from: directoryURL) ?? metadata
    }

    // MARK: - Read

    /// 读取单个技能（含正文）。技能不存在或文件不完整时返回 `nil`。
    ///
    /// 先查 `.lumi/skills`，未命中再查历史目录 `.agent/skills`。
    public func readSkill(projectPath: String, name: String) throws -> SkillMetadata? {
        let name = Self.sanitize(name)
        guard !name.isEmpty else { return nil }
        guard let directoryURL = locateSkillDirectory(projectPath: projectPath, name: name) else {
            return nil
        }
        guard Self.isCompleteSkillDirectory(directoryURL) else { return nil }
        return Self.loadMetadata(name: name, from: directoryURL)
    }

    // MARK: - Update

    /// 更新已有技能的元数据与正文。
    ///
    /// 两个写入内容都采用「`nil` 表示不改动」语义，保证只更新其中一个字段时
    /// 不会把另一个字段清空。
    ///
    /// 技能位于历史目录 `.agent/skills` 时在**原位**更新，不做隐式迁移。
    ///
    /// - Returns: 更新后的技能元数据。
    public func updateSkill(
        projectPath: String,
        name: String,
        title: String? = nil,
        description: String? = nil,
        triggers: [String]? = nil,
        content: String? = nil
    ) throws -> SkillMetadata {
        let name = Self.sanitize(name)
        guard let directoryURL = locateSkillDirectory(projectPath: projectPath, name: name) else {
            throw SkillCreationError.notFound(
                ProjectConfigDirectory.writeURL(
                    projectPath: projectPath,
                    component: SkillDirectoryNames.skills
                )
                .appendingPathComponent(name).path
            )
        }
        guard Self.isCompleteSkillDirectory(directoryURL) else {
            throw SkillCreationError.notFound(directoryURL.path)
        }

        // 以磁盘上的现有元数据为基底，只覆盖显式传入的字段。
        // 完整性检查已通过，这里解码失败说明 metadata.json 已损坏。
        guard let existing = Self.loadMetadata(name: name, from: directoryURL) else {
            throw SkillCreationError.invalidFile(directoryURL.appendingPathComponent("metadata.json").path)
        }
        let updated = SkillMetadata(
            name: name,
            title: title ?? existing.title,
            description: description ?? existing.description,
            triggers: triggers ?? existing.triggers,
            version: existing.version
        )

        if title != nil || description != nil || triggers != nil {
            try Self.writeMetadata(updated, to: directoryURL)
        }
        if let content {
            try Self.writeBody(content, to: directoryURL)
        }
        return Self.loadMetadata(name: name, from: directoryURL) ?? updated
    }

    // MARK: - Delete

    /// 删除技能目录（连同 `metadata.json` 与 `SKILL.md`）。
    ///
    /// 删除的是技能**实际所在**的目录（`.lumi/skills` 或历史目录 `.agent/skills`）。
    public func deleteSkill(projectPath: String, name: String) throws {
        let name = Self.sanitize(name)
        guard let directoryURL = locateSkillDirectory(projectPath: projectPath, name: name) else {
            throw SkillCreationError.notFound(
                ProjectConfigDirectory.writeURL(
                    projectPath: projectPath,
                    component: SkillDirectoryNames.skills
                )
                .appendingPathComponent(name).path
            )
        }
        try fileManager.removeItem(at: directoryURL)
    }

    // MARK: - 内部

    /// 定位技能目录（不创建目录）。
    ///
    /// 依次在 `.lumi/skills` 与历史目录 `.agent/skills` 中查找，返回第一个
    /// 已存在的技能目录；都不存在时返回 `nil`。
    private func locateSkillDirectory(projectPath: String, name: String) -> URL? {
        guard !name.isEmpty else { return nil }
        return ProjectConfigDirectory.locate(
            projectPath: projectPath,
            component: SkillDirectoryNames.skills,
            name: name
        )
    }

    /// 解析技能**写入**目录 URL（`.lumi/skills/<name>`，不创建目录）。
    private func makeWriteDirectory(projectPath: String, name: String) throws -> URL {
        let trimmed = projectPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw SkillCreationError.invalidName("project path is empty")
        }
        // 规范化后为空（如传入 "!!!"）会让路径退化到 skills 根目录，必须拒绝，
        // 否则 delete 可能删掉整个 skills 目录。
        guard !name.isEmpty else {
            throw SkillCreationError.invalidName("name is empty after normalization")
        }
        return ProjectConfigDirectory.writeURL(
            projectPath: trimmed,
            component: SkillDirectoryNames.skills
        )
        .appendingPathComponent(name, isDirectory: true)
    }

    /// 目录是否同时含 `metadata.json` 与 `SKILL.md`（扫描器的完整性要求）。
    private static func isCompleteSkillDirectory(_ directoryURL: URL) -> Bool {
        FileManager.default.fileExists(atPath: directoryURL.appendingPathComponent("metadata.json").path)
            && FileManager.default.fileExists(atPath: directoryURL.appendingPathComponent("SKILL.md").path)
    }

    /// 技能目录名规范化：转小写 kebab-case，并剔除一切路径分隔符与 `..`。
    ///
    /// 安全要点：目录名会直接拼进文件路径，因此必须保证规范化结果
    /// - 不含 `/`（否则可逃出 `.agent/skills`），
    /// - 不等于 `.` / `..`，
    /// - 非空。
    /// 违反任一条时返回空串，由调用方拒绝。
    static func sanitize(_ raw: String) -> String {
        let flattened = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            // 先把任何路径分隔符与相对路径标记折叠成连字符。
            .replacingOccurrences(of: "[/\\\\.]+", with: "-", options: .regularExpression)
            .replacingOccurrences(of: "[\\s_]+", with: "-", options: .regularExpression)
            .replacingOccurrences(of: "-{2,}", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        // 保留单个 `.`，其余标点剔除，避免空串之外再引入可导航的名字。
        return flattened.filter { $0.isLetter || $0.isNumber || $0 == "-" }
    }

    /// 从磁盘读取技能元数据（含 `contentPath`）。
    private static func loadMetadata(name: String, from directoryURL: URL) -> SkillMetadata? {
        let metadataURL = directoryURL.appendingPathComponent("metadata.json")
        let skillMDURL = directoryURL.appendingPathComponent("SKILL.md")
        guard let data = try? Data(contentsOf: metadataURL),
              let decoded = try? JSONDecoder().decode(SkillMetadata.self, from: data) else {
            return nil
        }
        let modifiedAt = (try? skillMDURL.resourceValues(forKeys: [.contentModificationDateKey]))?
            .contentModificationDate ?? Date()
        return SkillMetadata(
            name: decoded.name.isEmpty ? name : decoded.name,
            title: decoded.title,
            description: decoded.description,
            triggers: decoded.triggers,
            version: decoded.version,
            contentPath: skillMDURL.path,
            modifiedAt: modifiedAt
        )
    }

    private static func writeMetadata(_ metadata: SkillMetadata, to directoryURL: URL) throws {
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        // `SkillMetadata` 的 encode 只输出 name / title / description / triggers /
        // version，正好与扫描器解码的字段一致。
        let data = try encoder.encode(metadata)
        try data.write(to: directoryURL.appendingPathComponent("metadata.json"), options: .atomic)
    }

    private static func writeBody(_ body: String, to directoryURL: URL) throws {
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try body.write(to: directoryURL.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)
    }

    /// 组装 `SKILL.md`：frontmatter + 标题 + 正文。
    ///
    /// 正文已带 frontmatter 或以一级标题开头时视为完整内容，避免重复包装。
    static func makeSkillMarkdown(metadata: SkillMetadata, content: String?) -> String {
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
