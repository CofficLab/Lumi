import Foundation
import KernelLumi
import SuperLogKit

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

    public nonisolated func riskLevel(arguments: [String: LumiJSONValue], kernel: KernelLumi) -> LumiCommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: LumiJSONValue], kernel: KernelLumi) async throws -> String {
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
