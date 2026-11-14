import Foundation
import KitAgentTool
import Testing
@testable import PluginNetworkManager

/// 回归 #821：已收到 HTTP 状态码（4xx/5xx）的请求只归入 http_4xx/http_5xx，
/// 不得同时被当作 network 错误。network 类别只保留「未取得 HTTP 状态码」的
/// 传输失败；否则同一条 404 会在 Network 与 4xx 两个分类里重复出现、重复计数。
@MainActor
@Suite(.serialized, HTTPExchangeStoreGateTrait())
struct HTTPFailedRequestClassificationTests {

    @Test func networkFilterExcludesRecordsThatReceivedAnHTTPStatus() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("HTTPFailedNet-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = HTTPExchangeStore(directory: directory, startsRetentionMaintenance: false)
        let previousStore = NetworkService.shared.currentExchangeStore
        NetworkService.shared.configureHTTPExchangeStore(store)
        defer { NetworkService.shared.configureHTTPExchangeStore(previousStore) }

        let transportURL = try #require(URL(string: "https://transport.test/down"))
        let notFoundURL = try #require(URL(string: "https://api.test/missing"))
        let serverURL = try #require(URL(string: "https://api.test/broken"))

        // 传输失败：没有 HTTP 状态码，只有 errorDescription。
        recordFailure(store, url: transportURL, status: nil)
        // 4xx/5xx：既有状态码又有 errorDescription（生产路径写入 HTTPNetworkError）。
        recordFailure(store, url: notFoundURL, status: 404)
        recordFailure(store, url: serverURL, status: 500)

        let networkOnly = try await GetHTTPFailedRequestsTool().execute(arguments: [
            "error_types": ToolArgument(["network"]),
        ])
        #expect(networkOnly.contains("transport.test/down"))
        #expect(!networkOnly.contains("api.test/missing"), "404 已收到 HTTP 响应，不应被归为 network")
        #expect(!networkOnly.contains("api.test/broken"), "500 已收到 HTTP 响应，不应被归为 network")
        #expect(networkOnly.contains("**Summary**: 1 failed requests"))
        #expect(networkOnly.contains("- Network Errors: 1"))
    }

    @Test func summaryAndDetailsDoNotDoubleCountHTTPStatusErrors() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("HTTPFailedSum-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = HTTPExchangeStore(directory: directory, startsRetentionMaintenance: false)
        let previousStore = NetworkService.shared.currentExchangeStore
        NetworkService.shared.configureHTTPExchangeStore(store)
        defer { NetworkService.shared.configureHTTPExchangeStore(previousStore) }

        let transportURL = try #require(URL(string: "https://transport.test/down"))
        let notFoundURL = try #require(URL(string: "https://api.test/missing"))
        let serverURL = try #require(URL(string: "https://api.test/broken"))

        recordFailure(store, url: transportURL, status: nil)
        recordFailure(store, url: notFoundURL, status: 404)
        recordFailure(store, url: serverURL, status: 500)

        let summary = try await GetHTTPFailedRequestsTool().execute(arguments: [:])
        #expect(summary.contains("**Summary**: 3 failed requests"))
        #expect(summary.contains("- Network Errors: 1"))
        #expect(summary.contains("- HTTP 4xx Errors: 1"))
        #expect(summary.contains("- HTTP 5xx Errors: 1"))
        // 404 只应在 4xx 明细里出现一次；修复前会同时列在 Network 与 4xx 两处。
        let notFoundOccurrences = summary.components(separatedBy: "api.test/missing").count - 1
        #expect(notFoundOccurrences == 1, "404 被重复列入多个分类明细")
    }

    /// 构造一条失败记录：status 为 nil 表示纯传输失败（无 HTTP 状态码），
    /// 非 nil 表示已收到该 HTTP 状态码；两种情况都带 errorDescription，
    /// 复刻生产路径中「状态码 + 错误描述」同时落库的记录。
    private func recordFailure(_ store: HTTPExchangeStore, url: URL, status: Int?) {
        let startedAt = Date().addingTimeInterval(-60)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let exchange = store.begin(request: request, startedAt: startedAt)
        let response = status.flatMap {
            HTTPURLResponse(url: url, statusCode: $0, httpVersion: "HTTP/1.1", headerFields: nil)
        }
        store.finish(
            exchange,
            response: response,
            error: URLError(.notConnectedToInternet),
            finishedAt: startedAt.addingTimeInterval(0.5)
        )
    }
}