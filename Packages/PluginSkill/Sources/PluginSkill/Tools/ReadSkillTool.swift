import KitAgentTool
import Foundation

/// 读取项目技能工具
///
/// 返回单个技能的元数据 + `SKILL.md` 正文，供修改前先读原文。
public struct ReadSkillTool: SuperAgentTool {
    public let name = "read_skill"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Read a single project skill from the .lumi/skills directory, including its metadata and the full SKILL.md body. Use this before updating a skill so you edit the existing content instead of replacing it blindly."
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

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let projectPath = await SkillToolSupport.resolveProjectPath(arguments) else {
            throw SkillCreationError.invalidName("project_path is required (no current project selected)")
        }
        guard let name = SkillToolSupport.string(arguments, "name") else {
            throw SkillCreationError.invalidName("name is required")
        }

        guard let skill = try await SkillCreationService.shared.readSkill(
            projectPath: projectPath,
            name: name
        ) else {
            throw SkillCreationError.notFound("<project>/.lumi/skills/\(name)")
        }

        let result: [String: Any] = [
            "success": true,
            "skill": [
                "name": skill.name,
                "title": skill.title,
                "description": skill.description,
                "triggers": skill.triggers,
                "version": skill.version,
                "content_path": skill.contentPath,
                "content": skill.loadContent() ?? "",
            ],
        ]
        return try Self.encode(result)
    }

    private static func encode(_ object: Any) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted])
        return String(data: data, encoding: .utf8) ?? "{\"success\":false}"
    }
}
