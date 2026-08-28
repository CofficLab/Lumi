import Foundation

/// 把项目 Skill 列表构造成注入 LLM 的 system prompt。
public enum SkillPromptBuilder {
    public static func buildPrompt(skills: [SkillMetadata]) -> String {
        let lines = skills.map { skill in
            let trigger = skill.triggers.isEmpty ? "" : " (触发: \(skill.triggers.joined(separator: " / ")))"
            return "- \(skill.name): \(skill.description)\(trigger)"
        }
        return """
        ## Available Skills
        The current project provides the following skills. When a task matches a skill, apply it to guide your work.

        \(lines.joined(separator: "\n"))
        """
    }
}
