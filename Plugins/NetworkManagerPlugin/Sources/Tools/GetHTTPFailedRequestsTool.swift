import Foundation
import LumiKernel
import SuperLogKit

/// 查询失败请求的 Agent 工具。
public struct GetHTTPFailedRequestsTool: LumiAgentTool, SuperLog {
    public nonisolated static let emoji = "❌"
    public nonisolated static let verbose: Bool = false

    public nonisolated static let info = LumiAgentToolInfo(
        id: "get_http_failed_requests",
        displayName: "Get HTTP Failed Requests",
        description: "Query failed HTTP requests including network errors and HTTP error status codes."
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "limit": .object([
                    "type": .string("integer"),
                    "description": .string("Maximum number of records. Default: 20."),
                    "default": .int(20),
                ]),
                "hours": .object([
                    "type": .string("integer"),
                    "description": .string("Time window in hours. Default: 24."),
                    "default": .int(24),
                ]),
                "error_types": .object([
                    "type": .string("array"),
                    "items": .object(["type": .string("string")]),
                    "description": .string("Filter by type: 'network', 'http_4xx', 'http_5xx'."),
                ]),
            ]),
        ])
    }

    public nonisolated func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        "查询失败请求"
    }

    public nonisolated func riskLevel(arguments: [String: LumiJSONValue], kernel: LumiKernel) -> LumiCommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: LumiJSONValue], kernel: LumiKernel) async throws -> String {
        let limit = min(arguments.int("limit") ?? 20, 100)
        let hours = min(arguments.int("hours") ?? 24, 720)
        let errorTypes = arguments.stringArray("error_types")

        let result = await MainActor.run { () -> String in
            guard let store = NetworkService.shared.currentExchangeStore else {
                return "Error: HTTP exchange store not available"
            }

            let cutoff = Date().addingTimeInterval(-Double(hours) * 3600)
            let allRecords = store.fetchPage(limit: 5000)

            var failedRecords = allRecords.filter { record in
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

            failedRecords.sort { $0.startedAt > $1.startedAt }
            let results = Array(failedRecords.prefix(limit))

            if results.isEmpty {
                return "No failed requests found."
            }

            let networkErrors = results.filter { $0.errorDescription != nil }
            let http4xxErrors = results.filter { (($0.responseStatusCode ?? 0) >= 400 && ($0.responseStatusCode ?? 0) < 500) }
            let http5xxErrors = results.filter { ($0.responseStatusCode ?? 0) >= 500 }

            var sections: [String] = []
            sections.append("## Failed Requests (Last \(hours) hours)")
            sections.append("")
            sections.append("**Summary**: \(results.count) failed requests")
            sections.append("- Network Errors: \(networkErrors.count)")
            sections.append("- HTTP 4xx Errors: \(http4xxErrors.count)")
            sections.append("- HTTP 5xx Errors: \(http5xxErrors.count)")

            if !networkErrors.isEmpty {
                sections.append("")
                sections.append("### Network Errors")
                for record in networkErrors.prefix(10) {
                    sections.append("- [\(record.requestMethod)] \(record.requestURL)")
                    sections.append("  Error: \(record.errorDescription ?? "Unknown")")
                }
            }

            if !http4xxErrors.isEmpty {
                sections.append("")
                sections.append("### HTTP 4xx Client Errors")
                for record in http4xxErrors.prefix(10) {
                    sections.append("- [\(record.requestMethod)] \(record.requestURL)")
                    sections.append("  Status: \(record.responseStatusCode ?? 0)")
                }
            }

            if !http5xxErrors.isEmpty {
                sections.append("")
                sections.append("### HTTP 5xx Server Errors")
                for record in http5xxErrors.prefix(10) {
                    sections.append("- [\(record.requestMethod)] \(record.requestURL)")
                    sections.append("  Status: \(record.responseStatusCode ?? 0)")
                }
            }

            return sections.joined(separator: "\n")
        }

        return result
    }
}
