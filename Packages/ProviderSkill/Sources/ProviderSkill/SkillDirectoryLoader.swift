import Foundation

/// 从磁盘目录加载「Skill 集合」的通用工具。
///
/// 目录结构约定（与项目 `.agent/skills/` 一致）：每个子目录一个 Skill，
/// 内含 `metadata.json`（SkillMetadata 可解码字段）+ `SKILL.md`（正文）。
///
/// 三处来源共用本加载器，只是传入的目录不同：
/// - `PluginSkill` 读自己的 `Bundle.module` 资源目录（内置技能）；
/// - `SkillService` 读项目 `.agent/skills/` 目录（项目技能）；
/// - 任何第三方插件读自己的 `Bundle.module` 资源目录（插件贡献技能）。
///
/// 使用 `let` 属性 + 值语义，可安全跨 actor 传递。
public struct SkillDirectoryLoader: Sendable {
    /// metadata.json 最大字节数，防止恶意大文件。
    public let maxMetadataSize: Int
    /// 单个目录中最多加载的技能数。
    public let maxSkillCount: Int
    /// 是否按名称排序输出（默认 `true`，保证跨来源稳定顺序）。
    public let sortByName: Bool

    public init(maxMetadataSize: Int = 1_048_576, maxSkillCount: Int = 100, sortByName: Bool = true) {
        self.maxMetadataSize = maxMetadataSize
        self.maxSkillCount = maxSkillCount
        self.sortByName = sortByName
    }

    /// 加载给定目录下所有 Skill。
    ///
    /// - Parameter directoryURL: 技能根目录（不存在时返回空数组）。
    /// - Returns: 解析成功的技能列表；单个子目录解析失败（缺 metadata.json /
    ///   SKILL.md / 元数据非法）会被跳过，不中断整体加载。
    public func loadSkills(from directoryURL: URL) -> [SkillMetadata] {
        guard FileManager.default.fileExists(atPath: directoryURL.path) else {
            return []
        }
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var skills: [SkillMetadata] = []
        for itemURL in contents {
            if skills.count >= maxSkillCount { break }

            let resourceValues = try? itemURL.resourceValues(forKeys: [.isDirectoryKey])
            guard resourceValues?.isDirectory == true else { continue }
            guard let skill = loadSkill(at: itemURL) else { continue }
            skills.append(skill)
        }

        if sortByName {
            skills.sort { $0.name < $1.name }
        }
        return skills
    }

    /// 加载单个 Skill 目录（`metadata.json` + `SKILL.md`）。
    /// 解析失败返回 `nil`。
    public func loadSkill(at skillDirectoryURL: URL) -> SkillMetadata? {
        let metadataURL = skillDirectoryURL.appendingPathComponent("metadata.json")
        let skillMDURL = skillDirectoryURL.appendingPathComponent("SKILL.md")
        guard FileManager.default.fileExists(atPath: metadataURL.path),
              FileManager.default.fileExists(atPath: skillMDURL.path) else {
            return nil
        }

        guard let metadataAttrs = try? FileManager.default.attributesOfItem(atPath: metadataURL.path),
              let fileSize = metadataAttrs[.size] as? Int,
              fileSize <= maxMetadataSize,
              let data = try? Data(contentsOf: metadataURL),
              let skill = try? JSONDecoder().decode(SkillMetadata.self, from: data),
              !skill.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !skill.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        let modifiedAt = (try? skillMDURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date()
        return SkillMetadata(
            id: skill.name,
            name: skill.name,
            title: skill.title,
            description: skill.description,
            triggers: skill.triggers,
            version: skill.version,
            contentPath: skillMDURL.path,
            modifiedAt: modifiedAt
        )
    }
}