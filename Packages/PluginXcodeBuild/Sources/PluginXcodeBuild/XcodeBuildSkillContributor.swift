import Foundation
import ProviderSkill

/// Xcode Build 技能贡献者：演示第三方插件从自己的 `Resources/` 目录贡献 Skill。
///
/// 技能以标准目录格式存放在插件自己的资源目录（`Resources/Skills/`，
/// 每个子目录一个技能：`metadata.json` + `SKILL.md`），通过
/// `SkillDirectoryLoader` 解析——与`PluginSkill` 的内置目录、项目
/// `.agent/skills/` 共用同一套目录约定与解析器。
///
/// Package.swift 中须用 `.copy("Resources/Skills")` 保留目录结构，
/// 不能用 `.process`（后者可能扁平化/重命名资源导致目录遍历失败）。
public struct XcodeBuildSkillContributor: SkillContributing {
    public let providerID: String
    public let skills: [SkillMetadata]

    public init(
        providerID: String = XcodeBuildPlugin.pluginID,
        directoryName: String = "Skills"
    ) {
        self.providerID = providerID
        // Bundle.module 是当前 target 专属资源；SPM 资源文件夹默认复制到
        // bundle 根，故直接以 Skills 目录为根。
        let root = Bundle.module.resourceURL?.appendingPathComponent(directoryName, isDirectory: true)
        self.skills = SkillDirectoryLoader().loadSkills(from: root ?? URL(fileURLWithPath: "/nonexistent"))
    }

    public var allSkills: [SkillMetadata] { skills }
}