import Foundation
import LumiKernel

struct AgentRulesChatMiddleware: LumiSendMiddleware {
    func prepare(_ context: LumiSendContext) async throws -> LumiSendContext {
        var updated = context
        let projectPath = context.currentProjectPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !projectPath.isEmpty else {
            return updated
        }

        do {
            let rules = try await AgentRulesService.shared.listRules(projectPath: projectPath)
            guard !rules.isEmpty else {
                return updated
            }

            updated.systemPromptFragments.append(buildRulesPrompt(rules: rules))
        } catch {
            return updated
        }

        return updated
    }

    private func buildRulesPrompt(rules: [AgentRuleMetadata]) -> String {
        var lines = [
            "## Current Project Rules",
            "",
            "The current project has \(rules.count) rule document(s) in `.agent/rules/`.",
            "",
            "| Rule | Description |",
            "|------|-------------|"
        ]

        for rule in rules {
            let escapedDescription = rule.description
                .replacingOccurrences(of: "|", with: "\\|")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            lines.append("| \(rule.title) | \(escapedDescription) |")
        }

        lines.append("")
        lines.append("Use `list_agent_rules` or `create_agent_rule` when rule details are needed.")
        return lines.joined(separator: "\n")
    }
}
