import Foundation
import LumiKernel
import SuperLogKit

/// 查询最近 HTTP 交换记录的 Agent 工具。
///
/// 支持按请求方法、URL 关键词、时间范围和状态码筛选。
public struct ListHTTPExchangesTool: LumiAgentTool, SuperLog {
    public nonisolated static let emoji = "🔍"
    public nonisolated static let verbose: Bool = false

    public nonisolated static let info = LumiAgentToolInfo(
        id: "list_http_exchanges",
        displayName: "List HTTP Exchanges",
        description: "Query recent HTTP exchange records. Supports filtering by request method, URL keywords, time range, and status code. Returns formatted list of HTTP request/response pairs."
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "limit": .object([
                    "type": .string("integer"),
                    "description": .string("Maximum number of records to return. Default: 20, max: 100."),
                    "default": .int(20),
                ]),
                "method": .object([
                    "type": .string("string"),
                    "description": .string("Filter by HTTP method (GET, POST, PUT, DELETE, PATCH, etc.). Case-insensitive."),
                ]),
                "url_contains": .object([
                    "type": .string("string"),
                    "description": .string("Filter by URL containing this keyword."),
                ]),
                "status_code": .object([
                    "type": .string("integer"),
                    "description": .string("Filter by HTTP status code (e.g., 200, 404, 500)."),
                ]),
                "since": .object([
                    "type": .string("string"),
                    "description": .string("Filter exchanges after this date. Format: ISO8601."),
                ]),
                "before": .object([
                    "type": .string("string"),
                    "description": .string("Filter exchanges before this date. Format: ISO8601."),
                ]),
                "include_body": .object([
                    "type": .string("boolean"),
                    "description": .string("Whether to include request/response body snippets. Default: false."),
                ]),
            ]),
        ])
    }

    public nonisolated func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        "查询 HTTP 日志"
    }

    public nonisolated func riskLevel(arguments: [String: LumiJSONValue], kernel: LumiKernel) -> LumiCommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: LumiJSONValue], kernel: LumiKernel) async throws -> String {
        let limit = min(arguments.int("limit") ?? 20, 100)
        let method = arguments.string("method")?.uppercased()
        let urlContains = arguments.string("url_contains")
        let statusCode = arguments.int("status_code")
        let includeBody = arguments.bool("include_body") ?? false

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let since: Date?
        let before: Date?

        if let sinceStr = arguments.string("since") {
            since = formatter.date(from: sinceStr) ?? ISO8601DateFormatter().date(from: sinceStr)
        } else {
            since = nil
        }

        if let beforeStr = arguments.string("before") {
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
