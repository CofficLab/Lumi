import Foundation

/// Skill Prompt 构建器
///
/// 将 Skill 列表格式化为系统提示词，注入到 LLM 请求中。
public enum SkillPromptBuilder {
    /// 默认注入的最大 Skill 数量，控制 Token 消耗
    public static let defaultMaxSkills = 10

    /// 将 Skill 列表构建为系统提示词
    ///
    /// 生成 Markdown 表格格式的摘要，引导 LLM 识别并使用匹配的 Skill。
    /// 当 Skill 数量超过 `maxSkills` 时，只取前 N 个（已按名称排序的列表）。
    ///
    /// - Parameters:
    ///   - skills: 可用的 Skill 列表
    ///   - maxSkills: 注入的最大数量，默认 10
    /// - Returns: 格式化后的系统提示词
    public static func buildPrompt(
        skills: [SkillMetadata],
        maxSkills: Int = defaultMaxSkills,
        language: SkillPromptLanguage = .english
    ) -> String {
        var lines: [String] = []

        let truncated = Array(skills.prefix(maxSkills))

        lines.append(language == .chinese ? "## 可用 Skills" : "## Available Skills")

        if truncated.count < skills.count {
            lines.append("")
            switch language {
            case .chinese:
                lines.append("当前展示 \(truncated.count) / \(skills.count) 个 skills。")
            case .english:
                lines.append("Showing \(truncated.count) of \(skills.count) skills.")
            }
        }

        lines.append("")
        switch language {
        case .chinese:
            lines.append("你可以使用以下专用 skills。如果用户请求匹配某个 skill，请遵循它的说明和指南。")
        case .english:
            lines.append("You have access to the following specialized skills. If the user's request matches a skill, follow its instructions and guidelines.")
        }
        lines.append("")
        switch language {
        case .chinese:
            lines.append("| Skill | 描述 |")
            lines.append("|-------|------|")
        case .english:
            lines.append("| Skill | Description |")
            lines.append("|-------|-------------|")
        }

        for skill in truncated {
            let escapedName = escapeMarkdownInlineCode(skill.name)
            let escapedDescription = skill.description
                .replacingOccurrences(of: "|", with: "\\|")
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            lines.append("| `\(escapedName)` | \(escapedDescription) |")
        }

        lines.append("")
        switch language {
        case .chinese:
            lines.append("使用 skill 时，请在回复开头写 `[Skill: <skill-name>]` 表示已激活。")
        case .english:
            lines.append("When using a skill, start your response with: `[Skill: <skill-name>]` to indicate activation.")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - 私有方法

    /// 转义 Markdown 行内代码中的特殊字符
    ///
    /// 处理反引号和反斜杠，防止破坏 Markdown 表格格式。
    private static func escapeMarkdownInlineCode(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
    }
}

public enum SkillPromptLanguage: Sendable {
    case chinese
    case english
}
