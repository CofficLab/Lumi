import KitAgentTool
import Foundation
import KitSuperLog

/// 查询最近 HTTP 交换记录的 Agent 工具。
///
/// 支持按请求方法、URL 关键词、时间范围和状态码筛选。
struct ListHTTPExchangesTool: SuperAgentTool, SuperLog {
    nonisolated static let emoji = "🔍"
    nonisolated static let verbose: Bool = false

    let name = "list_http_exchanges"

    func description(for language: LanguagePreference) -> String {
        "Query recent HTTP exchange records. Supports filtering by request method, URL keywords, time range, and status code. Returns formatted list of HTTP request/response pairs."
    }

    func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "limit": [
                    "type": "integer",
                    "description": "Maximum number of records to return. Default: 20, max: 100.",
                ],
                "method": [
                    "type": "string",
                    "description": "Filter by HTTP method (GET, POST, PUT, DELETE, PATCH, etc.). Case-insensitive.",
                ],
                "url_contains": [
                    "type": "string",
                    "description": "Filter by URL containing this keyword.",
                ],
                "status_code": [
                    "type": "integer",
                    "description": "Filter by HTTP status code (e.g., 200, 404, 500).",
                ],
                "since": [
                    "type": "string",
                    "description": "Filter exchanges after this date. Format: ISO8601.",
                ],
                "before": [
                    "type": "string",
                    "description": "Filter exchanges before this date. Format: ISO8601.",
                ],
                "include_body": [
                    "type": "boolean",
                    "description": "Whether to include request/response body snippets. Default: false.",
                ],
            ],
        ]
    }

    func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "查询 HTTP 日志"
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        let limit = min(NetworkToolSupport.int(arguments, "limit") ?? 20, 100)
        let method = NetworkToolSupport.string(arguments, "method")?.uppercased()
        let urlContains = NetworkToolSupport.string(arguments, "url_contains")
        let statusCode = NetworkToolSupport.int(arguments, "status_code")
        let includeBody = NetworkToolSupport.bool(arguments, "include_body") ?? false

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let since: Date?
        let before: Date?

        if let sinceStr = NetworkToolSupport.string(arguments, "since") {
            since = formatter.date(from: sinceStr) ?? ISO8601DateFormatter().date(from: sinceStr)
        } else {
            since = nil
        }

        if let beforeStr = NetworkToolSupport.string(arguments, "before") {
            before = formatter.date(from: beforeStr) ?? ISO8601DateFormatter().date(from: beforeStr)
        } else {
            before = nil
        }

        let result = await MainActor.run { () -> String in
            guard let store = NetworkService.shared.currentExchangeStore else {
                return "Error: HTTP exchange store not available"
            }

            let allRecords = store.fetchPage(limit: 1000)
            var filtered = allRecords

            if let method {
                filtered = filtered.filter { $0.requestMethod.uppercased() == method }
            }

            if let urlContains {
                filtered = filtered.filter { $0.requestURL.localizedCaseInsensitiveContains(urlContains) }
            }

            if let statusCode {
                filtered = filtered.filter { $0.responseStatusCode == statusCode }
            }

            if let since {
                filtered = filtered.filter { $0.startedAt >= since }
            }

            if let before {
                filtered = filtered.filter { $0.startedAt <= before }
            }

            let results = Array(filtered.prefix(limit))

            if results.isEmpty {
                return "No HTTP exchanges found matching the criteria."
            }

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"

            let lines = results.enumerated().map { index, record in
                var line = "\(index + 1). [\(record.requestMethod)] \(record.requestURL)"
                line += "\n   Time: \(dateFormatter.string(from: record.startedAt))"

                if let duration = record.duration {
                    line += String(format: "\n   Duration: %.2fs", duration)
                }

                if let statusCode = record.responseStatusCode {
                    line += "\n   Status: \(statusCode) \(Self.statusText(statusCode))"
                }

                if let error = record.errorDescription {
                    line += "\n   Error: \(error)"
                }

                if includeBody {
                    if let reqBody = record.requestBody, !reqBody.isEmpty {
                        let snippet = String(data: reqBody.prefix(500), encoding: .utf8) ?? "<binary data>"
                        line += "\n   Request Body: \(snippet)"
                    }
                    if let respBody = record.responseBody, !respBody.isEmpty {
                        let snippet = String(data: respBody.prefix(500), encoding: .utf8) ?? "<binary data>"
                        line += "\n   Response Body: \(snippet)"
                    }
                }

                return line
            }

            return """
            Found \(filtered.count) matching exchanges (showing \(results.count)):

            \(lines.joined(separator: "\n\n"))
            """
        }

        return result
    }

    private static func statusText(_ code: Int) -> String {
        switch code {
        case 200: return "OK"
        case 201: return "Created"
        case 204: return "No Content"
        case 301: return "Moved Permanently"
        case 302: return "Found"
        case 304: return "Not Modified"
        case 400: return "Bad Request"
        case 401: return "Unauthorized"
        case 403: return "Forbidden"
        case 404: return "Not Found"
        case 405: return "Method Not Allowed"
        case 429: return "Too Many Requests"
        case 500: return "Internal Server Error"
        case 502: return "Bad Gateway"
        case 503: return "Service Unavailable"
        case 504: return "Gateway Timeout"
        default: return ""
        }
    }
}
