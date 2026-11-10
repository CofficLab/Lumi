import KitAgentTool
import Foundation
import LumiLoggingKit
/// 查询特定域名或路径的 HTTP 日志的 Agent 工具。
struct GetHTTPDomainLogTool: SuperAgentTool, SuperLog {
    nonisolated static let emoji = "🌐"
    nonisolated static let verbose: Bool = false

    let name = "get_http_domain_log"

    func description(for language: LanguagePreference) -> String {
        "Query HTTP logs for a specific domain or URL pattern."
    }

    func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "domain": [
                    "type": "string",
                    "description": "Domain or hostname to filter (e.g., 'api.github.com').",
                ],
                "path_prefix": [
                    "type": "string",
                    "description": "URL path prefix to filter.",
                ],
                "limit": [
                    "type": "integer",
                    "description": "Maximum number of records. Default: 50.",
                ],
                "hours": [
                    "type": "integer",
                    "description": "Time window in hours. Default: 24.",
                ],
            ],
            "required": ["domain"],
        ]
    }

    func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "查询域名日志"
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        let domain = NetworkToolSupport.string(arguments, "domain") ?? ""
        let pathPrefix = NetworkToolSupport.string(arguments, "path_prefix")
        let limit = NetworkToolSupport.limit(arguments, default: 50, max: 200)
        let hours = min(NetworkToolSupport.int(arguments, "hours") ?? 24, 720)

        guard !domain.isEmpty else {
            throw ToolExecutionError.executionFailed(toolName: name, reason: "domain parameter is required")
        }

        let result = try await MainActor.run { () throws -> String in
            guard let store = NetworkService.shared.currentExchangeStore else {
                throw ToolExecutionError.executionFailed(toolName: name, reason: "HTTP exchange store not available")
            }

            let cutoff = Date().addingTimeInterval(-Double(hours) * 3600)
            let domainLower = domain.lowercased()

            // Scan the whole retained history so the time window, not a hidden
            // record cap, decides what is included.
            let filtered = store.scanHistory { record in
                guard record.startedAt >= cutoff else { return false }
                guard let url = URL(string: record.url),
                      let host = url.host else { return false }

                let hostLower = host.lowercased()
                let domainMatches = hostLower == domainLower || hostLower.hasSuffix(".\(domainLower)")

                if !domainMatches { return false }

                if let pathPrefix, !pathPrefix.isEmpty {
                    return url.path.hasPrefix(pathPrefix)
                }

                return true
            }

            if filtered.isEmpty {
                return "No HTTP logs found for domain '\(domain)'."
            }

            var pathCounts: [String: Int] = [:]
            var methodCounts: [String: Int] = [:]
            var statusCounts: [Int: Int] = [:]

            for record in filtered {
                if let url = URL(string: record.url) {
                    pathCounts[url.path, default: 0] += 1
                }
                methodCounts[record.method, default: 0] += 1
                if let status = record.responseStatusCode {
                    statusCounts[status, default: 0] += 1
                }
            }

            var sections: [String] = []
            sections.append("## HTTP Logs for \(domain)")
            sections.append("")
            sections.append("**Total Requests**: \(filtered.count)")
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
            // `limit` 只约束明细条数，汇总始终覆盖全部匹配记录。
            for (path, count) in pathCounts.sorted(by: { $0.value > $1.value }).prefix(min(10, limit)) {
                sections.append("- \(path): \(count)")
            }

            return sections.joined(separator: "\n")
        }

        return result
    }
}
