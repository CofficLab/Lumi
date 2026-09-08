import Foundation
import ProviderSkill

/// Git 技能贡献者：从插件资源目录贡献 Git 版本控制技能。
///
/// 技能以标准目录格式存放在插件自己的资源目录
/// （`Resources/Skills/git/`：`metadata.json` + `SKILL.md`），
/// 通过 `SkillDirectoryLoader` 解析——与 `PluginXcodeBuild` 等插件的
/// 内置目录共用同一套目录约定与解析器。
///
/// Package.swift 中须用 `.copy("../../Resources/Skills")` 保留目录结构，
/// 不能用 `.process`（后者可能扁平化/重命名资源导致目录遍历失败）。
public struct GitSkillContributor: SkillContributing {
    public let providerID: String
    public let skills: [SkillMetadata]

    public init(
        providerID: String = GitSourceControlSuperPlugin.pluginID,
        directoryName: String = "Skills"
    ) {
        self.providerID = providerID
        let root = Bundle.module.resourceURL?.appendingPathComponent(directoryName, isDirectory: true)
        self.skills = SkillDirectoryLoader().loadSkills(from: root ?? URL(fileURLWithPath: "/nonexistent"))
    }

    public var allSkills: [SkillMetadata] { skills }
}
