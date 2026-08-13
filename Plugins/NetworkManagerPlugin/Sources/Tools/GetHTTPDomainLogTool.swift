import Foundation
import KernelLumi
import SuperLogKit

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

    public nonisolated func riskLevel(arguments: [String: LumiJSONValue], kernel: KernelLumi) -> LumiCommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: LumiJSONValue], kernel: KernelLumi) async throws -> String {
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
