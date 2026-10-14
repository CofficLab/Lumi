import KitAgentTool
import Foundation

/// 更新项目技能工具
///
/// 采用「省略即不改」语义：未传入的字段保持原值，避免只想改正文却把
/// 触发词清空。`content` 传空字符串表示清空正文。
public struct UpdateSkillTool: SuperAgentTool {
    public let name = "update_skill"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Update an existing project skill in the .agent/skills directory. Omitted fields keep their current values; provide 'content' to replace the SKILL.md body. Read the skill first with read_skill so the replacement is based on the existing content."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "project_path": [
                    "type": "string",
                    "description": "Absolute path to the project directory containing .agent/skills folder. Defaults to the current project.",
                ],
                "name": [
                    "type": "string",
                    "description": "Skill name (kebab-case) identifying the existing skill to update. It cannot be renamed; create a new skill instead.",
                ],
                "title": [
                    "type": "string",
                    "description": "New display title. Omit to keep the current title.",
                ],
                "description": [
                    "type": "string",
                    "description": "New one-sentence summary. Omit to keep the current description.",
                ],
                "triggers": [
                    "type": "array",
                    "items": ["type": "string"],
                    "description": "New trigger keywords. Omit to keep the current triggers; pass an empty array to clear them.",
                ],
                "content": [
                    "type": "string",
                    "description": "New SKILL.md body in Markdown, replacing the whole file. Omit to leave the body untouched.",
                ],
            ],
            "required": ["name"],
        ]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        guard let name = SkillToolSupport.string(arguments, "name") else { return "更新技能" }
        return "更新技能 \(name)"
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .medium
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let projectPath = await SkillToolSupport.resolveProjectPath(arguments) else {
            throw SkillCreationError.invalidName("project_path is required (no current project selected)")
        }
        guard let name = SkillToolSupport.string(arguments, "name") else {
            throw SkillCreationError.invalidName("name is required")
        }

        let title = SkillToolSupport.string(arguments, "title")
        let description = SkillToolSupport.string(arguments, "description")
        // triggers：区分「未传」与「传了空数组」。前者保持原值，后者清空。
        let triggers = SkillToolSupport.stringArrayAllowingEmpty(arguments, "triggers")
        // content 允许空串（清空正文），因此不能经过会丢弃空值的 string()。
        let content = arguments["content"]?.value as? String

        guard title != nil || description != nil || triggers != nil || content != nil else {
            throw SkillCreationError.invalidName(
                "provide at least one of: title, description, triggers, content"
            )
        }

        let skill = try await SkillCreationService.shared.updateSkill(
            projectPath: projectPath,
            name: name,
            title: title,
            description: description,
            triggers: triggers,
            content: content
        )
        await SkillService.shared.invalidateCache(projectPath: projectPath)

        let result: [String: Any] = [
            "success": true,
            "message": "Skill updated successfully",
            "skill": [
                "name": skill.name,
                "title": skill.title,
                "description": skill.description,
                "triggers": skill.triggers,
                "version": skill.version,
                "content_path": skill.contentPath,
            ],
        ]
        return try Self.encode(result)
    }

    private static func encode(_ object: Any) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted])
        return String(data: data, encoding: .utf8) ?? "{\"success\":false}"
    }
}
