import Foundation
import LumiKernel
import SuperLogKit

// MARK: - List HTTP Exchanges Tool

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

// MARK: - Get HTTP Summary Tool

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

    public nonisolated func riskLevel(arguments: [String: LumiJSONValue], kernel: LumiKernel) -> LumiCommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: LumiJSONValue], kernel: LumiKernel) async throws -> String {
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

// MARK: - Get HTTP Exchange Detail Tool

/// 查询特定 URL 的 HTTP 日志详情的 Agent 工具。
public struct GetHTTPExchangeDetailTool: LumiAgentTool, SuperLog {
    public nonisolated static let emoji = "🔎"
    public nonisolated static let verbose: Bool = false

    public nonisolated static let info = LumiAgentToolInfo(
        id: "get_http_exchange_detail",
        displayName: "Get HTTP Exchange Detail",
        description: "Get detailed information about a specific HTTP exchange by its ID or URL."
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "id": .object([
                    "type": .string("string"),
                    "description": .string("The UUID of the HTTP exchange record."),
                ]),
                "url": .object([
                    "type": .string("string"),
                    "description": .string("The URL to find the most recent exchange for."),
                ]),
                "include_body": .object([
                    "type": .string("boolean"),
                    "description": .string("Whether to include full bodies. Default: false."),
                    "default": .bool(false),
                ]),
            ]),
            "required": .array([.string("url")]),
        ])
    }

    public nonisolated func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        "查看 HTTP 详情"
    }

    public nonisolated func riskLevel(arguments: [String: LumiJSONValue], kernel: LumiKernel) -> LumiCommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: LumiJSONValue], kernel: LumiKernel) async throws -> String {
        let idStr = arguments.string("id")
        let url = arguments.string("url")
        let includeBody = arguments.bool("include_body") ?? false

        let result = await MainActor.run { () -> String in
            guard let store = NetworkService.shared.currentExchangeStore else {
                return "Error: HTTP exchange store not available"
            }

            let records = store.fetchPage(limit: 1000)

            let record: HTTPExchangeRecord?

            if let idStr, let uuid = UUID(uuidString: idStr) {
                record = records.first { $0.id == uuid }
            } else if let url {
                record = records.first { $0.requestURL.contains(url) }
            } else {
                record = nil
            }

            guard let record else {
                return "HTTP exchange not found."
            }

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"

            var sections: [String] = []
            sections.append("## HTTP Exchange Detail")
            sections.append("")
            sections.append("**ID**: \(record.id.uuidString)")
            sections.append("**Time**: \(dateFormatter.string(from: record.startedAt))")
            sections.append("")

            sections.append("### Request")
            sections.append("- **Method**: \(record.requestMethod)")
            sections.append("- **URL**: \(record.requestURL)")

            if let reqHeaders = Self.parseJSON(record.requestHeadersJSON) as? [String: String] {
                sections.append("- **Headers**:")
                for (key, value) in reqHeaders.sorted(by: { $0.key < $1.key }) {
                    sections.append("  - \(key): \(value)")
                }
            }

            if includeBody, let reqBody = record.requestBody, !reqBody.isEmpty {
                if let bodyStr = String(data: reqBody, encoding: .utf8) {
                    sections.append("- **Body**:\n```\n\(bodyStr.prefix(1000))\n```")
                }
            }

            sections.append("")
            sections.append("### Response")
            if let statusCode = record.responseStatusCode {
                sections.append("- **Status**: \(statusCode) \(Self.statusText(statusCode))")
            }
            if let mimeType = record.responseMIMEType {
                sections.append("- **Content-Type**: \(mimeType)")
            }
            if let respHeaders = record.responseHeadersJSON, let headers = Self.parseJSON(respHeaders) as? [String: String] {
                sections.append("- **Headers**:")
                for (key, value) in headers.sorted(by: { $0.key < $1.key }) {
                    sections.append("  - \(key): \(value)")
                }
            }

            sections.append("")
            sections.append("### Timing")
            if let duration = record.duration {
                sections.append("- **Duration**: \(String(format: "%.3f", duration))s")
            }

            if let errorDesc = record.errorDescription {
                sections.append("")
                sections.append("### Error")
                sections.append("- **Description**: \(errorDesc)")
            }

            return sections.joined(separator: "\n")
        }

        return result
    }

    private static func parseJSON(_ data: Data) -> Any? {
        try? JSONSerialization.jsonObject(with: data)
    }

    private static func statusText(_ code: Int) -> String {
        switch code {
        case 200: return "OK"
        case 400: return "Bad Request"
        case 401: return "Unauthorized"
        case 403: return "Forbidden"
        case 404: return "Not Found"
        case 500: return "Internal Server Error"
        case 502: return "Bad Gateway"
        case 503: return "Service Unavailable"
        default: return ""
        }
    }
}

// MARK: - Get HTTP Slow Requests Tool

/// 查询慢请求的 Agent 工具。
public struct GetHTTPSlowRequestsTool: LumiAgentTool, SuperLog {
    public nonisolated static let emoji = "🐌"
    public nonisolated static let verbose: Bool = false

    public nonisolated static let info = LumiAgentToolInfo(
        id: "get_http_slow_requests",
        displayName: "Get HTTP Slow Requests",
        description: "Query HTTP requests that took longer than a specified threshold."
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "threshold_seconds": .object([
                    "type": .string("number"),
                    "description": .string("Minimum duration in seconds. Default: 1.0."),
                    "default": .double(1.0),
                ]),
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
            ]),
        ])
    }

    public nonisolated func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        "查询慢请求"
    }

    public nonisolated func riskLevel(arguments: [String: LumiJSONValue], kernel: LumiKernel) -> LumiCommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: LumiJSONValue], kernel: LumiKernel) async throws -> String {
        let threshold = arguments.double("threshold_seconds") ?? 1.0
        let limit = min(arguments.int("limit") ?? 20, 100)
        let hours = min(arguments.int("hours") ?? 24, 720)

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

// MARK: - Get HTTP Failed Requests Tool

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

// MARK: - Get HTTP Domain Log Tool

/// 查询特定域名或路径的 HTTP 日志的 Agent 工具。
public struct GetHTTPDomainLogTool: LumiAgentTool, SuperLog {
    public nonisolated static let emoji = "🌐"
    public nonisolated static let verbose: Bool = false

    public nonisolated static let info = LumiAgentToolInfo(
        id: "get_http_domain_log",
        displayName: "Get HTTP Domain Log",
        description: "Query HTTP logs for a specific domain or URL pattern."
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "domain": .object([
                    "type": .string("string"),
                    "description": .string("Domain or hostname to filter (e.g., 'api.github.com')."),
                ]),
                "path_prefix": .object([
                    "type": .string("string"),
                    "description": .string("URL path prefix to filter."),
                ]),
                "limit": .object([
                    "type": .string("integer"),
                    "description": .string("Maximum number of records. Default: 50."),
                    "default": .int(50),
                ]),
                "hours": .object([
                    "type": .string("integer"),
                    "description": .string("Time window in hours. Default: 24."),
                    "default": .int(24),
                ]),
            ]),
            "required": .array([.string("domain")]),
        ])
    }

    public nonisolated func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        "查询域名日志"
    }

    public nonisolated func riskLevel(arguments: [String: LumiJSONValue], kernel: LumiKernel) -> LumiCommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: LumiJSONValue], kernel: LumiKernel) async throws -> String {
        let domain = arguments.string("domain") ?? ""
        let pathPrefix = arguments.string("path_prefix")
        let limit = min(arguments.int("limit") ?? 50, 200)
        let hours = min(arguments.int("hours") ?? 24, 720)

        guard !domain.isEmpty else {
            return "Error: domain parameter is required"
        }

        let result = await MainActor.run { () -> String in
            guard let store = NetworkService.shared.currentExchangeStore else {
                return "Error: HTTP exchange store not available"
            }

            let cutoff = Date().addingTimeInterval(-Double(hours) * 3600)
            let allRecords = store.fetchPage(limit: 5000)

            let filtered = allRecords.filter { record in
                guard record.startedAt >= cutoff else { return false }
                guard let url = URL(string: record.requestURL),
                      let host = url.host else { return false }

                let domainLower = domain.lowercased()
                let hostLower = host.lowercased()
                let domainMatches = hostLower == domainLower || hostLower.hasSuffix(".\(domainLower)")

                if !domainMatches { return false }

                if let pathPrefix, !pathPrefix.isEmpty {
                    return url.path.hasPrefix(pathPrefix)
                }

                return true
            }

            let results = Array(filtered.prefix(limit))

            if results.isEmpty {
                return "No HTTP logs found for domain '\(domain)'."
            }

            var pathCounts: [String: Int] = [:]
            var methodCounts: [String: Int] = [:]
            var statusCounts: [Int: Int] = [:]

            for record in results {
                if let url = URL(string: record.requestURL) {
                    pathCounts[url.path, default: 0] += 1
                }
                methodCounts[record.requestMethod, default: 0] += 1
                if let status = record.responseStatusCode {
                    statusCounts[status, default: 0] += 1
                }
            }

            var sections: [String] = []
            sections.append("## HTTP Logs for \(domain)")
            sections.append("")
            sections.append("**Total Requests**: \(results.count)")
            sections.append("")
            sections.append("### Request Methods")
            for (method, count) in methodCounts.sorted(by: { $0.value > $1.value }) {
                sections.append("- \(method): \(count)")
            }
            sections.append("")
            sections.append("### Status Codes")
            for (code, count) in statusCounts.sorted(by: { $0.key < $1.key }) {
                sections.append("- \(code): \(count)")
            }
            sections.append("")
            sections.append("### Top Paths")
            for (path, count) in pathCounts.sorted(by: { $0.value > $1.value }).prefix(10) {
                sections.append("- \(path): \(count)")
            }

            return sections.joined(separator: "\n")
        }

        return result
    }
}
