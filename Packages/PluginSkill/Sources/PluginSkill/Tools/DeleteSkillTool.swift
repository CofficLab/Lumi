import KitAgentTool
import Foundation
/// 删除项目技能工具
///
/// 递归删除技能目录（`.lumi/skills/<name>/`，历史目录 `.agent/skills/<name>/`
/// 中的技能同样可被删除）。
public struct DeleteSkillTool: SuperAgentTool {
    public let name = "delete_skill"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Delete a project skill from the .lumi/skills directory, removing its metadata.json and SKILL.md. Built-in and plugin-contributed skills cannot be deleted this way."
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
                    "description": "Skill name (kebab-case) of the skill to delete.",
                ],
            ],
            "required": ["name"],
        ]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        guard let name = SkillToolSupport.string(arguments, "name") else { return "删除技能" }
        return "删除技能 \(name)"
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        // 删除不可逆，按与 ShellTool 同级的较高风险处理。
        .high
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let projectPath = await SkillToolSupport.resolveProjectPath(arguments) else {
            throw SkillCreationError.invalidName("project_path is required (no current project selected)")
        }
        guard let name = SkillToolSupport.string(arguments, "name") else {
            throw SkillCreationError.invalidName("name is required")
        }

        try await SkillCreationService.shared.deleteSkill(projectPath: projectPath, name: name)
        await SkillService.shared.invalidateCache(projectPath: projectPath)

        let result: [String: Any] = [
            "success": true,
            "message": "Skill deleted successfully",
            "name": name,
            "directory_path": ProjectConfigDirectory
                .writeURL(projectPath: projectPath, component: "skills")
                .appendingPathComponent(name).path,
        ]
        let data = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted])
        return String(data: data, encoding: .utf8) ?? "{\"success\":false}"
    }
}
