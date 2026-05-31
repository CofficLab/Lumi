import Foundation
import AgentToolKit

struct CollectSubAgentTool: SuperAgentTool, SuperLog {
    nonisolated static let emoji = "📦"

    let name = "collect_subagent"

    func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "等待一个或多个内核级子 Agent 完成并收集结构化结果。"
        case .english:
            return "Wait for one or more kernel sub-agents to finish and collect structured results."
        }
    }

    func inputSchema(for language: LanguagePreference) -> [String: Any] {
        let taskIdsDesc: String
        let timeoutDesc: String

        switch language {
        case .chinese:
            taskIdsDesc = "spawn_subagent 返回的 task_id，多个 ID 用逗号分隔"
            timeoutDesc = "最长等待秒数，默认 120，范围 1-3600"
        case .english:
            taskIdsDesc = "task_id values returned by spawn_subagent, comma-separated for multiple IDs"
            timeoutDesc = "Maximum seconds to wait, default 120, range: 1-3600"
        }

        return [
            "type": "object",
            "properties": [
                "task_ids": [
                    "type": "string",
                    "description": taskIdsDesc,
                ],
                "timeout": [
                    "type": "integer",
                    "description": timeoutDesc,
                    "minimum": 1,
                    "maximum": 3600,
                ],
            ],
            "required": ["task_ids"],
        ]
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        try context.checkCancellation()

        guard let rawTaskIds = arguments["task_ids"]?.value as? String, !rawTaskIds.isEmpty else {
            throw KernelSubAgentError.missingArgument("task_ids")
        }

        let taskIds = rawTaskIds
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !taskIds.isEmpty else {
            return "Error: No valid task IDs provided."
        }

        let timeout = Self.normalizedTimeout(arguments["timeout"]?.value as? Int)
        let results = await SubAgentScheduler.shared.collect(taskIds: taskIds, timeout: timeout)

        return format(results: results)
    }

    func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "收集子 Agent 结果"
    }

    private func format(results: [KernelSubAgentResult]) -> String {
        var output = "# Sub-Agent Results\n\n"

        for result in results {
            let icon: String
            switch result.status {
            case .completed: icon = "Success"
            case .failed: icon = "Failed"
            case .cancelled: icon = "Cancelled"
            case .running: icon = "Running"
            }

            output += "## \(icon): \(result.name)\n"
            output += "- task_id: \(result.taskId)\n"
            output += "- type: \(result.type)\n"
            output += "- status: \(result.status.rawValue)\n"
            output += "- duration: \(String(format: "%.1f", result.duration))s\n"

            if !result.fields.isEmpty {
                output += "\n"
                for key in result.fields.keys.sorted() {
                    guard let value = result.fields[key], !value.isEmpty else { continue }
                    output += "- \(key): \(value)\n"
                }
            }

            if let error = result.error, !error.isEmpty {
                output += "\nError: \(error)\n"
            } else if result.fields.isEmpty, !result.rawOutput.isEmpty {
                output += "\n\(result.rawOutput)\n"
            }

            output += "\n---\n\n"
        }

        let completed = results.filter { $0.status == .completed }.count
        output += "Summary: \(completed)/\(results.count) sub-agents completed successfully."
        return output
    }

    static func normalizedTimeout(_ rawTimeout: Int?) -> TimeInterval {
        TimeInterval(min(max(rawTimeout ?? 120, 1), 3600))
    }
}
