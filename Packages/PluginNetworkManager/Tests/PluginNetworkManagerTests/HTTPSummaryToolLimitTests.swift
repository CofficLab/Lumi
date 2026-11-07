import Foundation
import KitAgentTool
import Testing
@testable import PluginNetworkManager

/// 汇总类 HTTP 工具：`limit` 只能裁剪明细，不能改变匹配总数。
@MainActor
@Suite(.serialized)
struct HTTPSummaryToolLimitTests {
    @Test func summariesCountAllMatchesWhileLimitOnlyCapsDetails() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("HTTPSummary-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = HTTPExchangeStore(directory: directory, startsRetentionMaintenance: false)
        let previousStore = NetworkService.shared.currentExchangeStore
        NetworkService.shared.configureHTTPExchangeStore(store)
        defer { NetworkService.shared.configureHTTPExchangeStore(previousStore) }

        let url = try #require(URL(string: "https://api.example.com/items"))
        for _ in 0..<30 {
            record(store, url: url, status: 200, duration: 0.1)
            record(store, url: url, status: 500, duration: 2.5)
        }

        let domainLog = try await GetHTTPDomainLogTool().execute(arguments: [
            "domain": ToolArgument("api.example.com"),
            "limit": ToolArgument(10),
        ])
        #expect(domainLog.contains("**Total Requests**: 60"))
        #expect(domainLog.contains("- 200: 30"))
        #expect(domainLog.contains("- 500: 30"))

        let failed = try await GetHTTPFailedRequestsTool().execute(arguments: [
            "limit": ToolArgument(10),
        ])
        #expect(failed.contains("**Summary**: 30 failed requests"))
        #expect(failed.contains("- HTTP 5xx Errors: 30"))
        #expect(failed.contains("Showing first 10 of 30"))

        let slow = try await GetHTTPSlowRequestsTool().execute(arguments: [
            "limit": ToolArgument(20),
            "threshold_seconds": ToolArgument(1.0),
        ])
        #expect(slow.contains("Found 30 slow requests"))
        #expect(slow.contains("showing 20"))
    }

    private func record(
        _ store: HTTPExchangeStore,
        url: URL,
        status: Int,
        duration: TimeInterval
    ) {
        let startedAt = Date().addingTimeInterval(-60)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let exchange = store.begin(request: request, startedAt: startedAt)
        let response = HTTPURLResponse(
            url: url,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        )
        store.finish(exchange, response: response, finishedAt: startedAt.addingTimeInterval(duration))
    }
}
