import Foundation
import SuperLogKit

/// Skill 扫描器协议
///
/// 抽象文件系统扫描能力，便于测试时注入 Mock 实现。
public protocol SkillScanning: Sendable {
    /// 扫描指定项目路径下的 `.agent/skills/` 目录
    func scanSkills(projectPath: String) -> [SkillMetadata]
}

/// 默认的文件系统扫描器
///
/// 扫描 `.agent/skills/` 目录，解析 `metadata.json`，验证 `SKILL.md` 存在。
/// 支持文件大小限制和元数据基础校验。
public struct SkillScanner: SkillScanning, SuperLog {
    public nonisolated static let emoji = "🔍"

    /// `metadata.json` 允许的最大字节数（默认 1 MB）
    public let maxMetadataSize: Int

    /// 单个目录下最多扫描的 Skill 数量
    public let maxSkillCount: Int

    public init(
        maxMetadataSize: Int = 1_048_576,
        maxSkillCount: Int = 100
    ) {
        self.maxMetadataSize = maxMetadataSize
        self.maxSkillCount = maxSkillCount
    }

    public func scanSkills(projectPath: String) -> [SkillMetadata] {
        let directoryURL = URL(fileURLWithPath: projectPath)
            .appendingPathComponent(".agent/skills")

        // 目录不存在时静默返回空
        guard FileManager.default.fileExists(atPath: directoryURL.path) else {
            if SkillPlugin.verbose {
                SkillPlugin.logger.info("\(Self.t)skills 目录不存在：\(directoryURL.path)")
            }
            return []
        }

        // 获取子目录
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            if SkillPlugin.verbose {
                SkillPlugin.logger.warning("\(Self.t)无法读取 skills 目录")
            }
            return []
        }

        var skills: [SkillMetadata] = []

        for itemURL in contents {
            if skills.count >= maxSkillCount { break }

            // 只处理目录
            let resourceValues = try? itemURL.resourceValues(forKeys: [.isDirectoryKey])
            guard resourceValues?.isDirectory == true else { continue }

            // 验证两个文件都存在
            let metadataURL = itemURL.appendingPathComponent("metadata.json")
            let skillMDURL = itemURL.appendingPathComponent("SKILL.md")

            guard FileManager.default.fileExists(atPath: metadataURL.path),
                  FileManager.default.fileExists(atPath: skillMDURL.path) else {
                if SkillPlugin.verbose {
                    SkillPlugin.logger.warning("\(Self.t)缺少 metadata.json 或 SKILL.md：\(itemURL.lastPathComponent)")
                }
                continue
            }

            // 校验 metadata.json 文件大小
            guard let metadataAttrs = try? FileManager.default.attributesOfItem(atPath: metadataURL.path),
                  let fileSize = metadataAttrs[.size] as? Int,
                  fileSize <= maxMetadataSize else {
                if SkillPlugin.verbose {
                    SkillPlugin.logger.warning("\(Self.t)metadata.json 超过大小限制：\(itemURL.lastPathComponent)")
                }
                continue
            }

            // 解析 metadata.json
            guard let data = try? Data(contentsOf: metadataURL),
                  let skill = try? JSONDecoder().decode(SkillMetadata.self, from: data) else {
                if SkillPlugin.verbose {
                    SkillPlugin.logger.error("\(Self.t)解析 metadata.json 失败：\(itemURL.lastPathComponent)")
                }
                continue
            }

            // 基础字段验证：name 和 title 不能为空或纯空白
            guard !skill.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !skill.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                if SkillPlugin.verbose {
                    SkillPlugin.logger.warning("\(Self.t)name 或 title 为空：\(itemURL.lastPathComponent)")
                }
                continue
            }

            // 填充文件系统信息
            let modifiedAt = (try? skillMDURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date()

            let completeSkill = SkillMetadata(
                id: skill.name,
                name: skill.name,
                title: skill.title,
                description: skill.description,
                triggers: skill.triggers,
                version: skill.version,
                contentPath: skillMDURL.path,
                modifiedAt: modifiedAt
            )

            skills.append(completeSkill)
        }

        // 按名称排序
        skills.sort { $0.name < $1.name }

        if SkillPlugin.verbose {
            SkillPlugin.logger.info("\(Self.t)扫描到 \(skills.count) 个 Skill")
        }

        return skills
    }
}
