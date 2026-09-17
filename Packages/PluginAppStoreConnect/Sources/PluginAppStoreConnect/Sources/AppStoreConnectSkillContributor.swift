import Foundation
import ProviderSkill

/// App Store Connect 技能贡献者：从插件资源目录加载 App Store Connect 工作流指南。
///
/// 技能使用标准目录格式存放在插件根目录的
/// `Resources/Skills/app-store-connect/`（`metadata.json` + `SKILL.md`），
/// 通过 `SkillDirectoryLoader` 加载，并由 `SkillProviding` 统一注入给 LLM。
public struct AppStoreConnectSkillContributor: SkillContributing {
    public let providerID: String
    public let skills: [SkillMetadata]

    public init(
        providerID: String = "com.coffic.lumi.plugin.app-store-connect",
        directoryName: String = "Skills"
    ) {
        self.providerID = providerID
        let root = Bundle.module.resourceURL?.appendingPathComponent(directoryName, isDirectory: true)
        self.skills = SkillDirectoryLoader().loadSkills(from: root ?? URL(fileURLWithPath: "/nonexistent"))
    }

    public var allSkills: [SkillMetadata] { skills }
}
