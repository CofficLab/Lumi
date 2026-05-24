import Foundation
import AgentToolKit

struct RunReviewTool: SuperAgentTool, SuperLog {
    nonisolated static let emoji = "🔎"
    nonisolated static let verbose: Bool = true

    let name = "run_review"
    let llmService: LLMService?

    func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "使用当前激活的 Lumi 模型审查 Git 变更。支持暂存区、未暂存或全部未提交变更。只读操作。"
        case .english:
            return "Review current Git changes using the active Lumi model. Supports staged, unstaged, or all uncommitted changes. Read-only."
        }
    }

    func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "path": [
                    "type": "string",
                    "description": "Git repository path. Defaults to current working directory."
                ],
                "scope": [
                    "type": "string",
                    "enum": ["staged", "unstaged", "allUncommitted"],
                    "description": "Review scope. Defaults to allUncommitted."
                ],
                "file": [
                    "type": "string",
                    "description": "Optional relative file path to review."
                ]
            ]
        ]
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        guard let llmService else {
            return "Code review failed: LLM service is unavailable."
        }

        let path = arguments["path"]?.value as? String ?? FileManager.default.currentDirectoryPath
        let scopeValue = arguments["scope"]?.value as? String ?? ReviewScope.allUncommitted.rawValue
        let scope = ReviewScope(rawValue: scopeValue) ?? .allUncommitted
        let file = arguments["file"]?.value as? String

        do {
            await ReviewReportStore.shared.setState(.reviewing)
            let context = try await ReviewAnalyzer().buildContext(repositoryPath: path, scope: scope, file: file)
            let config = await MainActor.run {
                RootContainer.shared.agentSessionConfig.getCurrentConfig()
            }
            let report = try await ReviewEngine(llmService: llmService, config: config).review(context: context)
            try await ReviewReportStore.shared.save(report)
            return format(report: report)
        } catch {
            await ReviewReportStore.shared.setState(.failed(message: error.localizedDescription))
            return "Code review failed: \(error.localizedDescription)"
        }
    }

    private func format(report: ReviewReport) -> String {
        let critical = report.issues.filter { $0.severity == .critical }
        let warnings = report.issues.filter { $0.severity == .warning }
        let infos = report.issues.filter { $0.severity == .info }

        var output = """
        ## Code Review

        **Report ID**: \(report.id.uuidString)
        **Scope**: \(report.scope.rawValue)
        **Score**: \(String(format: "%.1f", report.overallScore))/10
        **Diff**: \(report.diffStats.filesChanged) files, +\(report.diffStats.insertions), -\(report.diffStats.deletions)
        **Issues**: \(critical.count) critical, \(warnings.count) warnings, \(infos.count) info

        \(report.summary)
        """

        let displayed = Array(report.issues.prefix(12))
        if !displayed.isEmpty {
            output += "\n\n### Findings\n"
            for issue in displayed {
                let location = issue.line.map { ":\($0)" } ?? ""
                output += "\n- [\(issue.severity.rawValue)] `\(issue.file)\(location)` \(issue.description)"
                if !issue.rationale.isEmpty {
                    output += "\n  Rationale: \(issue.rationale)"
                }
                if let fix = issue.fixSuggestion, !fix.isEmpty {
                    output += "\n  Fix: \(fix)"
                }
            }
        }

        if report.issues.count > displayed.count {
            output += "\n\n_\(report.issues.count - displayed.count) additional findings omitted from this summary._"
        }

        return output
    }
}
