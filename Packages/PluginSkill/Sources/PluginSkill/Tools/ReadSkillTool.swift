import KitAgentTool
import Foundation
import ProviderSkill

/// 读取项目技能工具
///
/// 返回单个技能的元数据 + `SKILL.md` 正文，供修改前先读原文。
public struct ReadSkillTool: SuperAgentTool {
    public let name = "read_skill"

    /// 装配层注入的 `SkillProviding` 盒子：项目层未命中时回退的底座来源。
    private let skillProvider: SkillProvidingBox?

    public init(skillProvider: (any SkillProviding)? = nil) {
        self.skillProvider = SkillProvidingBox(skillProvider)
    }

    public func description(for language: LanguagePreference) -> String {
        "Read a single skill with its metadata and the full body. Project skills are read from the .lumi/skills directory; if the name is not found there, shared base skills (built-in and plugin-contributed) are searched. Use this before updating a project skill so you edit the existing content instead of replacing it blindly."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "project_path": [
                    "type": "string",
                    "description": "Absolute path to the project directory containing the .lumi/skills folder. Defaults to the current project.",
                ],
                "name": [
                    "type": "string",
                    "description": "Skill name (kebab-case), matching the directory name under .lumi/skills.",
                ],
            ],
            "required": ["name"],
        ]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        guard let name = SkillToolSupport.string(arguments, "name") else { return "读取技能" }
        return "读取技能 \(name)"
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .safe
    }

    public func executeResult(
        context: ToolExecutionContext,
        arguments: [String: ToolArgument]
    ) async throws -> ToolCallResult {
        ToolCallResult(content: try await execute(
            arguments: arguments,
            conversationProjectPath: await context.conversationProjectPath()
        ))
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        try await execute(arguments: arguments, conversationProjectPath: nil)
    }

    private func execute(
        arguments: [String: ToolArgument],
        conversationProjectPath: String?
    ) async throws -> String {
        let projectPath = await SkillToolSupport.resolveProjectPath(
            arguments,
            conversationProjectPath: conversationProjectPath
        )
        guard let name = SkillToolSupport.string(arguments, "name") else {
            throw SkillCreationError.invalidName("name is required")
        }

        // 项目层优先；未命中时回退底座（插件贡献 + 内置）。插件贡献的技能
        // 正文不在项目 .lumi/skills 目录里，read_skill 必须能读到它们，
        // 否则 LLM 只能拿到元数据（issue #294）。
        if let projectPath,
           let skill = try await SkillCreationService.shared.readSkill(
            projectPath: projectPath,
            name: name
           ) {
            return try Self.encode(skill: skill, content: try Self.readableContent(of: skill))
        }

        if let baseSkill = await Self.baseSkill(named: name, skillProvider: skillProvider) {
            return try Self.encode(
                skill: baseSkill,
                content: try Self.readableContent(of: baseSkill),
                source: "base"
            )
        }

        throw SkillCreationError.notFound(
            projectPath.map { _ in "<project>/.lumi/skills/\(name)" } ?? name
        )
    }

    /// 正文的 #527 语义：文件存在却读不出必须抛错，不得伪装成空正文；
    /// 真正的空文件 loadContent 返回 ""，仍正常返回。
    private static func readableContent(of skill: SkillMetadata) throws -> String {
        if let loaded = skill.loadContent() {
            return loaded
        }
        if FileManager.default.fileExists(atPath: skill.contentPath) {
            throw SkillCreationError.invalidFile(skill.contentPath)
        }
        return ""
    }

    /// 在底座（插件贡献 + 内置）中按名称查找技能。
    private static func baseSkill(
        named name: String,
        skillProvider: SkillProvidingBox?
    ) async -> SkillMetadata? {
        await skillProvider?.skill(named: name)
    }

    private static func encode(
        skill: SkillMetadata,
        content: String,
        source: String = "project"
    ) throws -> String {
        let result: [String: Any] = [
            "success": true,
            "skill": [
                "name": skill.name,
                "title": skill.title,
                "description": skill.description,
                "triggers": skill.triggers,
                "version": skill.version,
                "content_path": skill.contentPath,
                "content": content,
                "source": source,
            ],
        ]
        return try encodeObject(result)
    }

    private static func encodeObject(_ object: Any) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted])
        return String(data: data, encoding: .utf8) ?? "{\"success\":false}"
    }
}
