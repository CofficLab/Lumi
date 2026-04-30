import Foundation
import os

/// Skill 服务
///
/// 负责扫描 `.agent/skills/` 目录，解析 `metadata.json` 和验证 `SKILL.md`。
/// 使用内存缓存避免高频对话中重复扫描文件系统。
actor SkillService {
    // MARK: - 单例

    static let shared = SkillService()

    // MARK: - 属性

    /// 内存缓存：projectPath → (skills, timestamp)
    private var cachedSkills: [String: (skills: [SkillMetadata], timestamp: Date)] = [:]

    /// 缓存有效期（秒）
    private let cacheTTL: TimeInterval = 30

    // MARK: - 公开方法

    /// 获取指定项目的可用 Skill 列表
    ///
    /// 优先使用缓存，缓存过期或不存在时重新扫描文件系统。
    /// 目录不存在或为空时返回空数组，不抛出错误。
    func listSkills(projectPath: String) async -> [SkillMetadata] {
        // 检查缓存
        if let cached = cachedSkills[projectPath],
           Date().timeIntervalSince(cached.timestamp) < cacheTTL {
            return cached.skills
        }

        // 扫描文件系统
        let skills = scanSkills(projectPath: projectPath)

        // 更新缓存
        cachedSkills[projectPath] = (skills: skills, timestamp: Date())

        return skills
    }

    /// 加载 Skill 的完整内容（SKILL.md）
    ///
    /// - Parameter metadata: Skill 元数据
    /// - Returns: SKILL.md 的文本内容
    func loadContent(metadata: SkillMetadata) throws -> String {
        try String(contentsOfFile: metadata.contentPath, encoding: .utf8)
    }

    /// 清除指定项目的缓存
    func invalidateCache(projectPath: String) {
        cachedSkills.removeValue(forKey: projectPath)
    }

    // MARK: - 私有方法

    /// 获取 Skill 目录 URL
    private func getSkillsDirectoryURL(for projectPath: String) -> URL {
        URL(fileURLWithPath: projectPath).appendingPathComponent(".agent/skills")
    }

    /// 扫描指定目录下的所有 Skill
    private func scanSkills(projectPath: String) -> [SkillMetadata] {
        let directoryURL = getSkillsDirectoryURL(for: projectPath)

        // 目录不存在时静默返回空
        guard FileManager.default.fileExists(atPath: directoryURL.path) else {
            return []
        }

        // 获取子目录
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var skills: [SkillMetadata] = []

        for itemURL in contents {
            // 只处理目录
            let resourceValues = try? itemURL.resourceValues(forKeys: [.isDirectoryKey])
            guard resourceValues?.isDirectory == true else { continue }

            // 解析 metadata.json
            let metadataURL = itemURL.appendingPathComponent("metadata.json")
            let skillMDURL = itemURL.appendingPathComponent("SKILL.md")

            // 验证两个文件都存在
            guard FileManager.default.fileExists(atPath: metadataURL.path),
                  FileManager.default.fileExists(atPath: skillMDURL.path) else {
                continue
            }

            // 解析 metadata.json
            guard let data = try? Data(contentsOf: metadataURL),
                  var skill = try? JSONDecoder().decode(SkillMetadata.self, from: data) else {
                continue
            }

            // 填充文件系统信息
            let modifiedAt = (try? skillMDURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date()
            skill = SkillMetadata(
                id: skill.name,
                name: skill.name,
                title: skill.title,
                description: skill.description,
                triggers: skill.triggers,
                version: skill.version,
                contentPath: skillMDURL.path,
                modifiedAt: modifiedAt
            )

            skills.append(skill)
        }

        // 按名称排序
        skills.sort { $0.name < $1.name }

        return skills
    }
}
