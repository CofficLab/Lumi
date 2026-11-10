import KitAgentTool
import Foundation
import LumiLoggingKit
/// 查询失败请求的 Agent 工具。
struct GetHTTPFailedRequestsTool: SuperAgentTool, SuperLog {
    nonisolated static let emoji = "❌"
    nonisolated static let verbose: Bool = false

    let name = "get_http_failed_requests"

    func description(for language: LanguagePreference) -> String {
        "Query failed HTTP requests including network errors and HTTP error status codes."
    }

    func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "limit": [
                    "type": "integer",
                    "description": "Maximum number of records. Default: 20.",
                ],
                "hours": [
                    "type": "integer",
                    "description": "Time window in hours. Default: 24.",
                ],
                "error_types": [
                    "type": "array",
                    "items": ["type": "string"],
                    "description": "Filter by type: 'network', 'http_4xx', 'http_5xx'.",
                ],
            ],
        ]
    }

    func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "查询失败请求"
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        let limit = NetworkToolSupport.limit(arguments, default: 20, max: 100)
        let hours = min(NetworkToolSupport.int(arguments, "hours") ?? 24, 720)
        let errorTypes = NetworkToolSupport.stringArray(arguments, "error_types")

        let result = try await MainActor.run { () throws -> String in
            guard let store = NetworkService.shared.currentExchangeStore else {
                throw ToolExecutionError.executionFailed(toolName: name, reason: "HTTP exchange store not available")
            }

            let cutoff = Date().addingTimeInterval(-Double(hours) * 3600)

            // Scan the whole retained history so a matching failure older than
            // a fixed recent window is still reported.
            let failedRecords = store.scanHistory { record in
                guard record.startedAt >= cutoff else { return false }

                let hasNetworkError = record.errorDescription != nil
                let statusCode = record.responseStatusCode ?? 0
                let hasHTTPError = statusCode >= 400

                if let types = errorTypes, !types.isEmpty {
                    let isNetworkError = types.contains("network") && hasNetworkError
                    let isHTTP4xx = types.contains("http_4xx") && (statusCode >= 400 && statusCode < 500)
                    let isHTTP5xx = types.contains("http_5xx") && (statusCode >= 500)
                    return isNetworkError || isHTTP4xx || isHTTP5xx
                }

                return hasNetworkError || hasHTTPError
            }

            // `scanHistory` already yields newest first.
            // 汇总基于全部匹配记录；`limit` 只限制下方明细条数。
            let results = Array(failedRecords.prefix(limit))

            if failedRecords.isEmpty {
                return "No failed requests found."
            }

            let networkErrors = failedRecords.filter { $0.errorDescription != nil }
            let http4xxErrors = failedRecords.filter { (($0.responseStatusCode ?? 0) >= 400 && ($0.responseStatusCode ?? 0) < 500) }
            let http5xxErrors = failedRecords.filter { ($0.responseStatusCode ?? 0) >= 500 }

            var sections: [String] = []
            sections.append("## Failed Requests (Last \(hours) hours)")
            sections.append("")
            sections.append("**Summary**: \(failedRecords.count) failed requests")
            sections.append("- Network Errors: \(networkErrors.count)")
            sections.append("- HTTP 4xx Errors: \(http4xxErrors.count)")
            sections.append("- HTTP 5xx Errors: \(http5xxErrors.count)")
            if results.count < failedRecords.count {
                sections.append("- Showing first \(results.count) of \(failedRecords.count) detail records (limit: \(limit))")
            }

            let detailNetworkErrors = results.filter { $0.errorDescription != nil }
            let detailHTTP4xx = results.filter { (($0.responseStatusCode ?? 0) >= 400 && ($0.responseStatusCode ?? 0) < 500) }
            let detailHTTP5xx = results.filter { ($0.responseStatusCode ?? 0) >= 500 }

            if !detailNetworkErrors.isEmpty {
                sections.append("")
                sections.append("### Network Errors")
                for record in detailNetworkErrors.prefix(10) {
                    sections.append("- [\(record.method)] \(record.url)")
                    sections.append("  Error: \(record.errorDescription ?? "Unknown")")
                }
            }

            if !detailHTTP4xx.isEmpty {
                sections.append("")
                sections.append("### HTTP 4xx Client Errors")
                for record in detailHTTP4xx.prefix(10) {
                    sections.append("- [\(record.method)] \(record.url)")
                    sections.append("  Status: \(record.responseStatusCode ?? 0)")
                }
            }

            if !detailHTTP5xx.isEmpty {
                sections.append("")
                sections.append("### HTTP 5xx Server Errors")
                for record in detailHTTP5xx.prefix(10) {
                    sections.append("- [\(record.method)] \(record.url)")
                    sections.append("  Status: \(record.responseStatusCode ?? 0)")
                }
            }

            return sections.joined(separator: "\n")
        }

        return result
    }
}
