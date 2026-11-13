import Foundation
import KitAgentTool
import Testing
@testable import PluginNetworkManager

/// 回归 #825：URL scheme 按 RFC 3986 大小写不敏感，但 Foundation 保留输入
/// 原样（`URL(string: "HTTPS://…")?.scheme == "HTTPS"`）。
/// `network_download_file` 直接与 lowercase 字面量比较，会把合法的
/// 大写/混合大小写 HTTP/HTTPS 地址在发起请求前就拒绝掉。
@MainActor
@Suite(.serialized)
struct DownloadFileToolSchemeCaseTests {

    private final class StoreBox {
        let store: HTTPExchangeStore

        init(_ store: HTTPExchangeStore) {
            self.store = store
        }
    }

    private func makeStore() throws -> (store: HTTPExchangeStore, directory: URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DownloadFileToolScheme-\(UUID().uuidString)", isDirectory: true)
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

    @Test("大写/混合大小写的 HTTP/HTTPS scheme 必须走正常下载", arguments: [
        "HTTPS://files.example.com/report.bin",
        "HTTP://files.example.com/report.bin",
        "HtTpS://files.example.com/report.bin",
    ])
    func uppercaseSchemeDownloadsLikeLowercase(urlString: String) async throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }

        let downloadDirectory = root.appendingPathComponent("downloads", isDirectory: true)
        try FileManager.default.createDirectory(at: downloadDirectory, withIntermediateDirectories: true)

        let tool = makeTool(store: store, download: { request in
            (Data("payload".utf8), Self.httpResponse(url: request.url!, status: 200))
        })

        let result = try await tool.execute(arguments: [
            "url": ToolArgument(urlString),
            "filename": ToolArgument("report.bin"),
            "directory": ToolArgument(downloadDirectory.path),
        ])
        #expect(result.contains("下载完成"))
        #expect(FileManager.default.fileExists(
            atPath: downloadDirectory.appendingPathComponent("report.bin").path
        ))

        let records = store.fetchAll()
        #expect(records.count == 1, "大写 scheme 也必须进入真实下载并记录 exchange")
    }

    @Test("非 HTTP(S) 协议无论大小写仍被拒绝")
    func nonHTTPSchemesAreStillRejected() async throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }

        let tool = makeTool(store: store, download: { _ in
            Issue.record("被拒绝的协议不应发起下载")
            return (Data(), Self.httpResponse(url: URL(string: "ftp://example.com")!, status: 200))
        })

        for urlString in ["ftp://files.example.com/a.bin", "FTP://files.example.com/a.bin", "file:///etc/passwd"] {
            await #expect(throws: ToolExecutionError.self) {
                _ = try await tool.execute(arguments: [
                    "url": ToolArgument(urlString),
                    "directory": ToolArgument(root.path),
                ])
            }
        }
        #expect(store.fetchAll().isEmpty)
    }
}