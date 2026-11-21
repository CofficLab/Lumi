import KitAgentTool
import Foundation
import ProviderSkill

/// 列出项目技能工具
///
/// 返回 `.lumi/skills` 下所有技能 + 可用的通用底座（插件贡献 / 内置），
/// 让模型知道当前能创建什么、修改什么、什么已经被占用。
public struct ListSkillsTool: SuperAgentTool {
    static let maxLimit = 200

    public let name = "list_skills"

    /// 装配层注入的 `SkillProviding` 盒子：底座层由此聚合（插件贡献 + 内置）。
    private let skillProvider: SkillProvidingBox?

    public init(skillProvider: (any SkillProviding)? = nil) {
        self.skillProvider = SkillProvidingBox(skillProvider)
    }

    public func description(for language: LanguagePreference) -> String {
        "List available skills. Returns project skills from the .lumi/skills directory plus the shared base skills (built-in and plugin-contributed), including each skill's name, title, description, triggers and content path."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "project_path": [
                    "type": "string",
                    "description": "Absolute path to the project directory containing the .lumi/skills folder. Defaults to the current project.",
                ],
                "include_base": [
                    "type": "boolean",
                    "description": "Include shared base skills (built-in and plugin-contributed) in addition to project skills. Default: true.",
                ],
                "include_content": [
                    "type": "boolean",
                    "description": "Include the full SKILL.md body of each skill. Default: false (metadata only).",
                ],
                "limit": [
                    "type": "integer",
                    "description": "Maximum number of skills to return. Default: all.",
                    "minimum": 0,
                    "maximum": Self.maxLimit,
                ],
            ],
            "required": [],
        ]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String { "列出技能" }

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
        let includeBase = (arguments["include_base"]?.value as? Bool) ?? true
        let includeContent = (arguments["include_content"]?.value as? Bool) ?? false

        var skills: [SkillMetadata] = []
        if let projectPath {
            skills = await SkillService.shared.listSkills(projectPath: projectPath, baseSkills: [])
        }
        let projectNames = Set(skills.map(\.name))
        if includeBase {
            // 底座与项目层同名去重：项目技能优先（与 SkillMergePolicy 语义一致）。
            // 底座必须走 SkillProviding 聚合通道，否则插件贡献的技能
            // （如 xcode-build）只在 prompt 元数据里出现，list_skills 却看不到（#294）。
            let base = await Self.baseSkills(skillProvider: skillProvider)
            skills += base.filter { !projectNames.contains($0.name) }
        }
        skills.sort { $0.name < $1.name }

        if let limit = SkillToolSupport.int(arguments, "limit") {
            skills = Array(skills.prefix(max(0, min(limit, Self.maxLimit))))
        }

        guard !skills.isEmpty else {
            let hint = projectPath == nil
                ? "No project is selected and no base skills are available."
                : "No skills found under .lumi/skills, and no base skills are available."
            return hint
        }

        let payload: [[String: Any]] = skills.map { skill in
            var item: [String: Any] = [
                "name": skill.name,
                "title": skill.title,
                "description": skill.description,
                "triggers": skill.triggers,
                "version": skill.version,
                "is_project_skill": projectNames.contains(skill.name),
            ]
            // 工具描述承诺返回正文路径，与 read/update/create 的回执保持一致（#790）。
            // 插件贡献的技能可能只携带 content，路径为空时省略该键。
            if !skill.contentPath.isEmpty {
                item["content_path"] = skill.contentPath
            }
            if includeContent, let content = skill.loadContent() {
                item["content"] = content
            }
            return item
        }

        let result: [String: Any] = [
            "count": payload.count,
            "skills": payload,
        ]
        return try Self.encode(result)
    }

    // MARK: - 内部

    /// 底座技能（插件贡献 + 内置）。装配层注入了 `SkillProviding` 时走聚合
    /// 通道；未注入（工具单测 / 降级装配）时回退随包内置目录。
    private static func baseSkills(skillProvider: SkillProvidingBox?) async -> [SkillMetadata] {
        guard let skillProvider, skillProvider.hasProvider else {
            return await SkillService.shared.listBuiltinSkills()
        }
        return await skillProvider.allSkills()
    }

    private static func encode(_ object: Any) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted])
        return String(data: data, encoding: .utf8) ?? "{\"count\":0,\"skills\":[]}"
    }
}
