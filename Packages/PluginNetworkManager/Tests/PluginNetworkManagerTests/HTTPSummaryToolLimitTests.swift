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

    /// 回归：这些失败曾经返回 "Error: ..." / "❌ ..." 字符串，默认
    /// `executeResult` 会把它包成 `isError == false` 的成功结果。
    @Test func toolsThrowWhenExchangeStoreIsUnavailable() async throws {
        let previousStore = NetworkService.shared.currentExchangeStore
        NetworkService.shared.configureHTTPExchangeStore(nil)
        defer { NetworkService.shared.configureHTTPExchangeStore(previousStore) }

        await #expect(throws: ToolExecutionError.self) {
            _ = try await GetHTTPSummaryTool().executeResult(arguments: [:])
        }
        await #expect(throws: ToolExecutionError.self) {
            _ = try await GetHTTPFailedRequestsTool().executeResult(arguments: [:])
        }
        await #expect(throws: ToolExecutionError.self) {
            _ = try await GetHTTPSlowRequestsTool().executeResult(arguments: [:])
        }
        await #expect(throws: ToolExecutionError.self) {
            _ = try await ListHTTPExchangesTool().executeResult(arguments: [:])
        }
        await #expect(throws: ToolExecutionError.self) {
            _ = try await GetHTTPExchangeDetailTool().executeResult(arguments: [:])
        }
    }

    @Test func toolsThrowForInvalidArguments() async throws {
        await #expect(throws: ToolExecutionError.self) {
            _ = try await GetHTTPDomainLogTool().executeResult(arguments: [:])
        }
        await #expect(throws: ToolExecutionError.self) {
            _ = try await DownloadFileTool().executeResult(arguments: ["url": ToolArgument("not a url")])
        }
    }

    @Test func exchangeDetailThrowsWhenRecordIsMissing() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("HTTPDetail-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = HTTPExchangeStore(directory: directory, startsRetentionMaintenance: false)
        let previousStore = NetworkService.shared.currentExchangeStore
        NetworkService.shared.configureHTTPExchangeStore(store)
        defer { NetworkService.shared.configureHTTPExchangeStore(previousStore) }

        await #expect(throws: ToolExecutionError.self) {
            _ = try await GetHTTPExchangeDetailTool().executeResult(arguments: [
                "id": ToolArgument(UUID().uuidString),
            ])
        }
    }

    /// 回归 #664：四个查询工具曾经只加载固定数量的最新记录再过滤，
    /// 落在窗口之外的旧匹配即使仍在保留期内也会被遗漏。
    @Test func filtersFindMatchesOlderThanTheFormerFetchWindow() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("HTTPWindow-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = HTTPExchangeStore(directory: directory, startsRetentionMaintenance: false)
        let previousStore = NetworkService.shared.currentExchangeStore
        NetworkService.shared.configureHTTPExchangeStore(store)
        defer { NetworkService.shared.configureHTTPExchangeStore(previousStore) }

        let fillerURL = try #require(URL(string: "https://filler.test/ping"))
        let targetURL = try #require(URL(string: "https://legacy.test/old-endpoint"))
        // 旧窗口分别是 1,000 与 5,000 条，取 5,001 条让目标落在两者之外。
        let recordCount = 5_001
        let base = Date().addingTimeInterval(-3_600)

        for index in 0..<recordCount {
            let startedAt = base.addingTimeInterval(Double(index) * 0.001)
            let url = index == 0 ? targetURL : fillerURL
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            if index == 0 {
                request.httpBody = Data("payload".utf8)
            }
            let exchange = store.begin(request: request, startedAt: startedAt)
            if index == 0 {
                let response = HTTPURLResponse(
                    url: url,
                    statusCode: 500,
                    httpVersion: "HTTP/1.1",
                    headerFields: nil
                )
                store.finish(
                    exchange,
                    response: response,
                    finishedAt: startedAt.addingTimeInterval(2.5)
                )
            }
        }

        let listed = try await ListHTTPExchangesTool().execute(arguments: [
            "url_contains": ToolArgument("legacy.test"),
            "include_body": ToolArgument(true),
        ])
        #expect(listed.contains("Found 1 matching exchanges"))
        #expect(listed.contains("legacy.test/old-endpoint"))
        #expect(listed.contains("Request Body: payload"))

        let domainLog = try await GetHTTPDomainLogTool().execute(arguments: [
            "domain": ToolArgument("legacy.test"),
        ])
        #expect(domainLog.contains("**Total Requests**: 1"))

        let failed = try await GetHTTPFailedRequestsTool().execute(arguments: [:])
        #expect(failed.contains("**Summary**: 1 failed requests"))
        #expect(failed.contains("legacy.test/old-endpoint"))

        let slow = try await GetHTTPSlowRequestsTool().execute(arguments: [
            "threshold_seconds": ToolArgument(1.0),
        ])
        #expect(slow.contains("Found 1 slow requests"))
        #expect(slow.contains("legacy.test/old-endpoint"))
    }

    /// 回归 #663：detail 工具曾经只查最新 1,000 条，仍保留的旧记录会被
    /// 报告为不存在。
    @Test func exchangeDetailFindsRecordOlderThanTheFormerWindow() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("HTTPDetailWindow-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = HTTPExchangeStore(directory: directory, startsRetentionMaintenance: false)
        let previousStore = NetworkService.shared.currentExchangeStore
        NetworkService.shared.configureHTTPExchangeStore(store)
        defer { NetworkService.shared.configureHTTPExchangeStore(previousStore) }

        let fillerURL = try #require(URL(string: "https://filler.test/ping"))
        let targetURL = try #require(URL(string: "https://legacy.test/old-endpoint"))
        let base = Date().addingTimeInterval(-3_600)
        var oldestID: String?

        for index in 0..<1_001 {
            let startedAt = base.addingTimeInterval(Double(index) * 0.001)
            let url = index == 0 ? targetURL : fillerURL
            let exchange = store.begin(request: URLRequest(url: url), startedAt: startedAt)
            if index == 0 {
                oldestID = exchange?.id.uuidString
            }
        }

        let id = try #require(oldestID)

        let byID = try await GetHTTPExchangeDetailTool().execute(arguments: [
            "id": ToolArgument(id),
        ])
        #expect(byID.contains("## HTTP Exchange Detail"))
        #expect(byID.contains("legacy.test/old-endpoint"))

        let byURL = try await GetHTTPExchangeDetailTool().execute(arguments: [
            "url": ToolArgument("legacy.test"),
        ])
        #expect(byURL.contains("legacy.test/old-endpoint"))
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
