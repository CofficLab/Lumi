import Foundation
import ProviderAgentRules

/// 把项目规则和插件贡献规则构造成一次请求的 system prompt。
public enum AgentRulePromptBuilder {
    /// 项目规则优先于插件规则；相同 ID 只注入一次。
    public static func buildPrompt(
        projectRules: [AgentRuleDefinition],
        contributedRules: [AgentRuleDefinition]
    ) -> String? {
        var seenIDs: Set<String> = []
        let sections = projectRules.map { ("Project", $0) } + contributedRules.map { ("Plugin", $0) }
        let uniqueSections = sections.compactMap { source, rule -> (String, AgentRuleDefinition)? in
            guard !rule.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !seenIDs.contains(rule.id) else { return nil }
            seenIDs.insert(rule.id)
            return (source, rule)
        }

        guard !uniqueSections.isEmpty else { return nil }

        let body = uniqueSections.map { source, rule in
            """
            ### \(source) Rule: \(rule.title)
            \(rule.content.trimmingCharacters(in: .whitespacesAndNewlines))
            """
        }.joined(separator: "\n\n")

        return """
        ## Agent Rules
        Apply the following rules when they are relevant to the current task. Project rules take precedence over plugin rules with the same ID.

        \(body)
        """
    }
}
