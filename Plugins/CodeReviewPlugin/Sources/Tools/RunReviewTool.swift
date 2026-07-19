import Foundation
import LumiKernel
import SuperLogKit

public struct RunReviewTool: LumiAgentTool, SuperLog {
    public nonisolated static let emoji = "🔎"
    public nonisolated static let verbose: Bool = true

    public static let info = LumiAgentToolInfo(
        id: "run_review",
        displayName: "Run Review",
        description: "Review current Git changes using the active Lumi model. Supports staged, unstaged, or all uncommitted changes. Read-only."
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "path": .object([
                    "type": .string("string"),
                    "description": .string("Git repository path. Defaults to current working directory."),
                ]),
                "scope": .object([
                    "type": .string("string"),
                    "enum": .array([.string("staged"), .string("unstaged"), .string("allUncommitted")]),
                    "description": .string("Review scope. Defaults to allUncommitted."),
                ]),
                "file": .object([
                    "type": .string("string"),
                    "description": .string("Optional relative file path to review."),
                ]),
            ]),
        ])
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        "代码审查"
    }

    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        guard let sendMessage = CodeReviewRuntime.sendMessage,
              let config = CodeReviewRuntime.currentConfigProvider() else {
            return "Code review failed: LLM service is unavailable."
        }

        let path = arguments.string("path") ?? FileManager.default.currentDirectoryPath
        let scopeValue = arguments.string("scope") ?? ReviewScope.allUncommitted.rawValue
        let scope = ReviewScope(rawValue: scopeValue) ?? .allUncommitted
        let file = arguments.string("file")

        do {
            await ReviewReportStore.shared.setState(.reviewing)
            let reviewContext = try await ReviewAnalyzer().buildContext(repositoryPath: path, scope: scope, file: file)
            let report = try await ReviewEngine(config: config, sendMessage: sendMessage).review(context: reviewContext)
            try await ReviewReportStore.shared.save(report)
            return format(report: report)
        } catch {
            await ReviewReportStore.shared.setState(.failed(message: error.localizedDescription))
            return "Code review failed: \(error.localizedDescription)"
        }
    }

    /// Format a review report into a human-readable summary string (pure).
    /// Internal so it can be unit-tested directly.
    func format(report: ReviewReport) -> String {
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
