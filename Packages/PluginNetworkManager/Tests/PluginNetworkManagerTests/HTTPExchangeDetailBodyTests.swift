import Foundation
import KitAgentTool
import Testing
@testable import PluginNetworkManager

/// 回归 #311：`get_http_exchange_detail` 的 `include_body=true` 承诺同时给出
/// 请求与响应正文，但修复前 Response 段只输出状态码 / MIME / Headers，永远拿不到
/// `responseBody`。响应正文必须沿用与请求相同的规则（UTF-8 解码、截断到 1000
/// 字符），未请求时两者都不得输出。
@MainActor
@Suite(.serialized, HTTPExchangeStoreGateTrait())
struct HTTPExchangeDetailBodyTests {

    @Test func detailIncludesResponseBodyWhenRequested() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let id = try #require(recordExchange(
            store,
            url: "https://api.test/detail",
            requestBody: Data("request-payload-ABC".utf8),
            responseBody: Data("response-payload-XYZ".utf8),
            status: 200
        ))

        let output = try await GetHTTPExchangeDetailTool().execute(arguments: [
            "id": ToolArgument(id.uuidString),
            "include_body": ToolArgument(true),
        ])

        #expect(output.contains("request-payload-ABC"), "请求正文仍应输出")
        #expect(output.contains("response-payload-XYZ"), "include_body=true 必须输出响应正文，不得丢失")

        // 响应正文必须落在 Response 段，而不是 Request 段。
        let responseSection = try #require(output.range(of: "### Response"))
        let bodyOccurrence = try #require(output.range(of: "response-payload-XYZ"))
        #expect(responseSection.lowerBound < bodyOccurrence.lowerBound, "响应正文应出现在 Response 段之后")
    }

    @Test func detailOmitsBodiesWhenNotRequested() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let id = try #require(recordExchange(
            store,
            url: "https://api.test/nobody",
            requestBody: Data("request-payload-ABC".utf8),
            responseBody: Data("response-payload-XYZ".utf8),
            status: 200
        ))

        let explicitFalse = try await GetHTTPExchangeDetailTool().execute(arguments: [
            "id": ToolArgument(id.uuidString),
            "include_body": ToolArgument(false),
        ])
        #expect(!explicitFalse.contains("request-payload-ABC"), "include_body=false 不得输出请求正文")
        #expect(!explicitFalse.contains("response-payload-XYZ"), "include_body=false 不得输出响应正文")

        // 缺省（不传 include_body）等价于 false。
        let defaulted = try await GetHTTPExchangeDetailTool().execute(arguments: [
            "id": ToolArgument(id.uuidString),
        ])
        #expect(!defaulted.contains("request-payload-ABC"))
        #expect(!defaulted.contains("response-payload-XYZ"))
    }

    @Test func detailResponseBodyHonorsSameLengthLimitAsRequest() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let longBody = "HEAD_MARKER" + String(repeating: "x", count: 2000) + "TAIL_MARKER"
        let id = try #require(recordExchange(
            store,
            url: "https://api.test/long",
            requestBody: nil,
            responseBody: Data(longBody.utf8),
            status: 200
        ))

        let output = try await GetHTTPExchangeDetailTool().execute(arguments: [
            "id": ToolArgument(id.uuidString),
            "include_body": ToolArgument(true),
        ])

        #expect(output.contains("HEAD_MARKER"), "响应正文开头应保留")
        #expect(!output.contains("TAIL_MARKER"), "响应正文必须与请求一样截断到 1000 字符，超出部分不得输出")
    }

    @Test func detailSkipsNonUTF8ResponseBodyLikeRequest() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let id = try #require(recordExchange(
            store,
            url: "https://api.test/binary",
            requestBody: Data([0xFF, 0xFE]),
            responseBody: Data([0xFF, 0xFE, 0xFD]),
            status: 200
        ))

        let output = try await GetHTTPExchangeDetailTool().execute(arguments: [
            "id": ToolArgument(id.uuidString),
            "include_body": ToolArgument(true),
        ])

        // 非 UTF-8 正文与请求一样被跳过：输出里不应出现任何正文代码块围栏。
        #expect(output.contains("### Response"))
        #expect(!output.contains("```"), "无法 UTF-8 解码的正文不得输出代码块")
    }

    // MARK: - Helpers

    /// 建立临时 store 并注入进程级单例；返回 store 与目录，调用方负责 defer
    /// 清理目录。套件经 `HTTPExchangeStoreGateTrait` 串行化，不会与其它注入
    /// store 的套件互相抢指针。
    private func makeStore() throws -> (HTTPExchangeStore, URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("HTTPDetailBody-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = HTTPExchangeStore(directory: directory, startsRetentionMaintenance: false)
        NetworkService.shared.configureHTTPExchangeStore(store)
        return (store, directory)
    }

    private func recordExchange(
        _ store: HTTPExchangeStore,
        url: String,
        requestBody: Data?,
        responseBody: Data?,
        status: Int
    ) -> UUID? {
        let startedAt = Date().addingTimeInterval(-60)
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = "POST"
        request.httpBody = requestBody
        let exchange = store.begin(request: request, startedAt: startedAt)
        let response = HTTPURLResponse(
            url: URL(string: url)!,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )
        store.finish(
            exchange,
            response: response,
            body: responseBody,
            finishedAt: startedAt.addingTimeInterval(0.5)
        )
        return exchange?.id
    }
}