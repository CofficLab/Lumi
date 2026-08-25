import KitAgentTool
import Foundation
import KitSuperLog

/// 查询慢请求的 Agent 工具。
struct GetHTTPSlowRequestsTool: SuperAgentTool, SuperLog {
    nonisolated static let emoji = "🐌"
    nonisolated static let verbose: Bool = false

    let name = "get_http_slow_requests"

    func description(for language: LanguagePreference) -> String {
        "Query HTTP requests that took longer than a specified threshold."
    }

    func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "threshold_seconds": [
                    "type": "number",
                    "description": "Minimum duration in seconds. Default: 1.0.",
                ],
                "limit": [
                    "type": "integer",
                    "description": "Maximum number of records. Default: 20.",
                ],
                "hours": [
                    "type": "integer",
                    "description": "Time window in hours. Default: 24.",
                ],
            ],
        ]
    }

    func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "查询慢请求"
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        let threshold = NetworkToolSupport.double(arguments, "threshold_seconds") ?? 1.0
        let limit = min(NetworkToolSupport.int(arguments, "limit") ?? 20, 100)
        let hours = min(NetworkToolSupport.int(arguments, "hours") ?? 24, 720)

        let result = await MainActor.run { () -> String in
            guard let store = NetworkService.shared.currentExchangeStore else {
                return "Error: HTTP exchange store not available"
            }

            let cutoff = Date().addingTimeInterval(-Double(hours) * 3600)
            let allRecords = store.fetchPage(limit: 5000)

            let slowRequests = allRecords
                .filter { record in
                    guard let duration = record.duration, duration >= threshold else { return false }
                    return record.startedAt >= cutoff
                }
                .sorted { ($0.duration ?? 0) > ($1.duration ?? 0) }
                .prefix(limit)

            if slowRequests.isEmpty {
                return "No slow requests (>=\(String(format: "%.1f", threshold))s) found."
            }

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

            let lines = slowRequests.enumerated().map { index, record in
                var line = "\(index + 1). [\(record.requestMethod)] \(record.requestURL)"
                line += String(format: "\n   Duration: %.2fs", record.duration ?? 0)
                line += "\n   Time: \(dateFormatter.string(from: record.startedAt))"
                if let statusCode = record.responseStatusCode {
                    line += "\n   Status: \(statusCode)"
                }
                return line
            }

            return """
            Found \(slowRequests.count) slow requests (>=\(String(format: "%.1f", threshold))s):

            \(lines.joined(separator: "\n\n"))
            """
        }

        return result
    }
}
