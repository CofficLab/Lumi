import AgentToolKit
import Foundation
import SuperLogKit

/// 查询特定 URL 的 HTTP 日志详情的 Agent 工具。
struct GetHTTPExchangeDetailTool: SuperAgentTool, SuperLog {
    nonisolated static let emoji = "🔎"
    nonisolated static let verbose: Bool = false

    let name = "get_http_exchange_detail"

    func description(for language: LanguagePreference) -> String {
        "Get detailed information about a specific HTTP exchange by its ID or URL."
    }

    func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "id": [
                    "type": "string",
                    "description": "The UUID of the HTTP exchange record.",
                ],
                "url": [
                    "type": "string",
                    "description": "The URL to find the most recent exchange for.",
                ],
                "include_body": [
                    "type": "boolean",
                    "description": "Whether to include full bodies. Default: false.",
                ],
            ],
            "required": ["url"],
        ]
    }

    func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "查看 HTTP 详情"
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        let idStr = NetworkToolSupport.string(arguments, "id")
        let url = NetworkToolSupport.string(arguments, "url")
        let includeBody = NetworkToolSupport.bool(arguments, "include_body") ?? false

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
