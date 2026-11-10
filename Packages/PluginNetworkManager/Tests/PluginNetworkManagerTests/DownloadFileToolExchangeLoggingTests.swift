import Foundation
import KitAgentTool
import Testing
@testable import PluginNetworkManager

/// 回归 #977：`network_download_file` 必须写入 HTTP exchange，否则 HTTP Logs、
/// 统计与 domain 导出都会静默漏掉这次下载。
@MainActor
@Suite(.serialized)
struct DownloadFileToolExchangeLoggingTests {

    /// 让测试注入独立 store，而不去改写其它测试共用的 `NetworkService.shared`。
    private final class StoreBox {
        let store: HTTPExchangeStore

        init(_ store: HTTPExchangeStore) {
            self.store = store
        }
    }

    private func makeStore() throws -> (store: HTTPExchangeStore, directory: URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DownloadFileTool-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = HTTPExchangeStore(directory: directory, startsRetentionMaintenance: false)
        return (store, directory)
    }

    private func makeTool(
        store: HTTPExchangeStore,
        download: @escaping DownloadFileTool.DownloadHandler
    ) -> DownloadFileTool {
        let box = StoreBox(store)
        return DownloadFileTool(download: download, exchangeStore: { box.store })
    }

    private nonisolated static func httpResponse(url: URL, status: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: url,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/octet-stream"]
        )!
    }

    @Test func successfulDownloadIsRecordedInExchangeLog() async throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }

        let downloadDirectory = root.appendingPathComponent("downloads", isDirectory: true)
        try FileManager.default.createDirectory(at: downloadDirectory, withIntermediateDirectories: true)

        let tool = makeTool(store: store, download: { request in
            (Data("payload".utf8), Self.httpResponse(url: request.url!, status: 200))
        })

        let result = try await tool.execute(arguments: [
            "url": ToolArgument("https://files.example.com/report.bin"),
            "filename": ToolArgument("report.bin"),
            "directory": ToolArgument(downloadDirectory.path),
        ])
        #expect(result.contains("下载完成"))
        #expect(FileManager.default.fileExists(
            atPath: downloadDirectory.appendingPathComponent("report.bin").path
        ))

        let records = store.fetchAll()
        #expect(records.count == 1)
        let record = try #require(records.first)
        #expect(record.requestMethod == "GET")
        #expect(record.requestURL == "https://files.example.com/report.bin")
        #expect(record.responseStatusCode == 200)
        #expect(record.responseBody == Data("payload".utf8))
        #expect(record.finishedAt != nil)
        #expect(record.duration != nil)
    }

    @Test func failedDownloadIsRecordedWithError() async throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }

        let tool = makeTool(store: store, download: { _ in
            throw URLError(.timedOut)
        })

        await #expect(throws: ToolExecutionError.self) {
            _ = try await tool.execute(arguments: [
                "url": ToolArgument("https://files.example.com/ko.bin"),
                "filename": ToolArgument("ko.bin"),
                "directory": ToolArgument(root.path),
            ])
        }

        let records = store.fetchAll()
        #expect(records.count == 1)
        let record = try #require(records.first)
        #expect(record.requestURL == "https://files.example.com/ko.bin")
        #expect(record.errorDomain == NSURLErrorDomain)
        #expect(record.errorCode == NSURLErrorTimedOut)
        #expect(record.responseStatusCode == nil)
        #expect(record.finishedAt != nil)
    }

    @Test func non2xxDownloadIsRecordedWithStatus() async throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }

        let tool = makeTool(store: store, download: { request in
            (Data("denied".utf8), Self.httpResponse(url: request.url!, status: 500))
        })

        await #expect(throws: ToolExecutionError.self) {
            _ = try await tool.execute(arguments: [
                "url": ToolArgument("https://files.example.com/boom"),
                "filename": ToolArgument("boom.bin"),
                "directory": ToolArgument(root.path),
            ])
        }

        let records = store.fetchAll()
        #expect(records.count == 1)
        let record = try #require(records.first)
        #expect(record.responseStatusCode == 500)
        #expect(record.responseBody == Data("denied".utf8))
    }
}
