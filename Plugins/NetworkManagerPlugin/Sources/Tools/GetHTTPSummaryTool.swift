import Foundation
import KernelLumi
import SuperLogKit

/// 获取 HTTP 日志统计摘要的 Agent 工具。
public struct GetHTTPSummaryTool: LumiAgentTool, SuperLog {
    public nonisolated static let emoji = "📊"
    public nonisolated static let verbose: Bool = false

    public nonisolated static let info = LumiAgentToolInfo(
        id: "get_http_summary",
        displayName: "Get HTTP Summary",
        description: "Get statistical summary of HTTP exchanges including request method distribution, status code distribution, average response time, and error rate."
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "hours": .object([
                    "type": .string("integer"),
                    "description": .string("Time window in hours to analyze. Default: 24, max: 720 (30 days)."),
                    "default": .int(24),
                ]),
            ]),
        ])
    }

    public nonisolated func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        "HTTP 日志统计"
    }

    public nonisolated func riskLevel(arguments: [String: LumiJSONValue], kernel: KernelLumi) -> LumiCommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: LumiJSONValue], kernel: KernelLumi) async throws -> String {
        let hours = min(arguments.int("hours") ?? 24, 720)

        let result = await MainActor.run { () -> String in
            guard let store = NetworkService.shared.currentExchangeStore else {
                return "Error: HTTP exchange store not available"
            }

            let cutoff = Date().addingTimeInterval(-Double(hours) * 3600)
            let allRecords = store.fetchPage(limit: 10000)
            let records = allRecords.filter { $0.startedAt >= cutoff }

            if records.isEmpty {
                return "No HTTP exchanges in the last \(hours) hours."
            }

            let total = records.count
            let completed = records.filter { $0.finishedAt != nil }.count
            let failed = records.filter { $0.errorDescription != nil }.count

            var methodCounts: [String: Int] = [:]
            for record in records {
                methodCounts[record.requestMethod, default: 0] += 1
            }
            let topMethods = methodCounts.sorted { $0.value > $1.value }.prefix(5)

            var statusCounts: [Int: Int] = [:]
            for record in records where record.responseStatusCode != nil {
                statusCounts[record.responseStatusCode!, default: 0] += 1
            }
            let topStatuses = statusCounts.sorted { $0.value > $1.value }.prefix(5)

            let durations = records.compactMap { $0.duration }
            let avgDuration = durations.isEmpty ? 0 : durations.reduce(0, +) / Double(durations.count)
            let maxDuration = durations.max() ?? 0
            let minDuration = durations.min() ?? 0

            let errorRate = total > 0 ? Double(failed) / Double(total) * 100 : 0

            var sections: [String] = []
            sections.append("## HTTP Exchange Summary (Last \(hours) hours)")
            sections.append("")
            sections.append("### Overview")
            sections.append("- Total Requests: \(total)")
            sections.append("- Completed: \(completed)")
            sections.append("- Failed: \(failed)")
            sections.append("- Error Rate: \(String(format: "%.1f", errorRate))%")
            sections.append("")
            sections.append("### Response Time")
            sections.append(String(format: "- Average: %.2fs", avgDuration))
            sections.append(String(format: "- Min: %.2fs", minDuration))
            sections.append(String(format: "- Max: %.2fs", maxDuration))
            sections.append("")
            sections.append("### Request Methods")
            for (method, count) in topMethods {
                let pct = Double(count) / Double(total) * 100
                sections.append("- \(method): \(count) (\(String(format: "%.1f", pct))%)")
            }
            sections.append("")
            sections.append("### Status Codes")
            for (code, count) in topStatuses {
                let pct = Double(count) / Double(total) * 100
                sections.append("- \(code): \(count) (\(String(format: "%.1f", pct))%)")
            }

            return sections.joined(separator: "\n")
        }

        return result
    }
}
