import KitAgentTool
import Foundation
/// 创建项目技能工具
///
/// 在指定项目的 `.lumi/skills/<name>/` 下创建 `metadata.json` + `SKILL.md`，
/// 创建后立即被 `SkillService` 扫描识别（同目录约定）。
public struct CreateSkillTool: SuperAgentTool {
    public let name = "create_skill"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Create a new skill in the .lumi/skills directory of a project. The skill is written as metadata.json plus a SKILL.md body, and becomes available to the agent immediately."
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
                    "description": "Skill name and directory name in kebab-case (e.g. swiftui-standards). Whitespace and underscores are normalized automatically.",
                ],
                "title": [
                    "type": "string",
                    "description": "Human readable skill title. Defaults to name when omitted.",
                ],
                "description": [
                    "type": "string",
                    "description": "One sentence summary used when the skill is injected into the system prompt.",
                ],
                "triggers": [
                    "type": "array",
                    "items": ["type": "string"],
                    "description": "Trigger keywords that help the model decide when to apply this skill.",
                ],
                "content": [
                    "type": "string",
                    "description": "SKILL.md body in Markdown. Frontmatter and a level 1 heading are added automatically when missing. If the text already starts with '---' it is used verbatim.",
                ],
            ],
            "required": ["name", "description"],
        ]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        let name = (arguments["name"]?.value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.map { "创建技能 \($0)" } ?? "创建技能"
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .medium
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        // 优先使用显式参数，fallback 到当前项目。
        let explicitPath = (arguments["project_path"]?.value as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let currentPath: String? = await MainActor.run { SkillRuntime.currentProjectPath }
        let projectPath = explicitPath ?? currentPath

        guard let projectPath, !projectPath.isEmpty else {
            throw SkillCreationError.invalidName("project_path is required (no current project selected)")
        }

        guard let rawName = arguments["name"]?.value as? String,
              !rawName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SkillCreationError.invalidName("name is required")
        }

        let description = (arguments["description"]?.value as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !description.isEmpty else {
            throw SkillCreationError.invalidName("description is required")
        }

        let title = (arguments["title"]?.value as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let content = arguments["content"]?.value as? String
        let triggers = (arguments["triggers"]?.value as? [String])?
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty } ?? []

        let skill = try await SkillCreationService.shared.createSkill(
            projectPath: projectPath,
            name: rawName,
            title: title,
            description: description,
            triggers: triggers,
            content: content
        )

        // 新技能必须立刻可见，否则同一轮对话里模型无法引用刚创建的技能。
        await SkillService.shared.invalidateCache(projectPath: projectPath)

        let result: [String: Any] = [
            "success": true,
            "message": "Skill created successfully",
            "skill": [
                "name": skill.name,
                "title": skill.title,
                "description": skill.description,
                "triggers": skill.triggers,
                "version": skill.version,
                "directory_path": ProjectConfigDirectory
                    .writeURL(projectPath: projectPath, component: "skills")
                    .appendingPathComponent(skill.name).path,
                "content_path": skill.contentPath,
            ],
        ]

        let data = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted])
        return String(data: data, encoding: .utf8) ?? "{\"success\":false}"
    }
}
