import Foundation
import LumiCoreKit

struct AgentRulesChatMiddleware: LumiSendMiddleware {
    func prepare(_ context: LumiSendContext) async throws -> LumiSendContext {
        var updated = context
        let projectPath = ChatMiddlewareRuntime.currentProjectPath.value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !projectPath.isEmpty else {
            return updated
        }

        let rules = Self.loadRuleSummaries(projectPath: projectPath)
        guard !rules.isEmpty else {
            return updated
        }

        var lines = [
            "## Current Project Rules",
            "The project has \(rules.count) rule document(s) in `.agent/rules/`.",
            "| Rule | Description |",
            "|------|-------------|"
        ]

        for rule in rules {
            lines.append("| \(rule.title) | \(rule.description) |")
        }

        updated.systemPromptFragments.append(lines.joined(separator: "\n"))
        return updated
    }

    private struct RuleSummary {
        let title: String
        let description: String
    }

    private static func loadRuleSummaries(projectPath: String) -> [RuleSummary] {
        let directory = URL(fileURLWithPath: projectPath).appendingPathComponent(".agent/rules", isDirectory: true)
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return files
            .filter { $0.pathExtension == "md" }
            .compactMap { file in
                guard let content = try? String(contentsOf: file, encoding: .utf8) else {
                    return nil
                }

                let title = content
                    .split(whereSeparator: \.isNewline)
                    .first
                    .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "# ")) }
                    ?? file.deletingPathExtension().lastPathComponent

                let description = content
                    .split(whereSeparator: \.isNewline)
                    .dropFirst()
                    .first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
                    .map { String($0).trimmingCharacters(in: .whitespaces) }
                    ?? ""

                return RuleSummary(title: title, description: description)
            }
    }
}
