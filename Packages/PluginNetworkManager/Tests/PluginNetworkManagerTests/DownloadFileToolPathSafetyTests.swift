import Foundation
import KitAgentTool
import Testing
@testable import PluginNetworkManager

/// 回归 #448：`network_download_file` 的 `filename` 此前直接
/// `appendingPathComponent` 后写入，`"../victim"` 会逃出所选目录，
/// 嵌套/绝对路径同样不受约束，且会静默覆盖已有文件。
@MainActor
@Suite(.serialized)
struct DownloadFileToolPathSafetyTests {

    private final class StoreBox {
        let store: HTTPExchangeStore

        init(_ store: HTTPExchangeStore) {
            self.store = store
        }
    }

    private func makeStore() throws -> (store: HTTPExchangeStore, directory: URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DownloadFileToolPathSafety-\(UUID().uuidString)", isDirectory: true)
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

    @Test("逃出目录或嵌套的文件名被拒绝，且不发起下载", arguments: [
        "../victim",
        "sub/file.bin",
        "..",
        ".",
    ])
    func escapingOrNestedFilenameIsRejected(filename: String) async throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let downloadDirectory = root.appendingPathComponent("downloads", isDirectory: true)
        try FileManager.default.createDirectory(at: downloadDirectory, withIntermediateDirectories: true)

        let tool = makeTool(store: store, download: { request in
            (Data("payload".utf8), Self.httpResponse(url: request.url!, status: 200))
        })

        await #expect(throws: ToolExecutionError.self) {
            _ = try await tool.execute(arguments: [
                "url": ToolArgument("https://files.example.com/report.bin"),
                "filename": ToolArgument(filename),
                "directory": ToolArgument(downloadDirectory.path),
            ])
        }
        #expect(store.fetchAll().isEmpty, "非法文件名必须在发起下载前被拒绝")
        #expect(
            !FileManager.default.fileExists(atPath: root.appendingPathComponent("victim").path),
            "不得写出目录之外的文件"
        )
    }

    @Test("绝对路径文件名被拒绝")
    func absoluteFilenameIsRejected() async throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let downloadDirectory = root.appendingPathComponent("downloads", isDirectory: true)
        try FileManager.default.createDirectory(at: downloadDirectory, withIntermediateDirectories: true)
        let outside = root.appendingPathComponent("evil.bin")

        let tool = makeTool(store: store, download: { request in
            (Data("payload".utf8), Self.httpResponse(url: request.url!, status: 200))
        })

        await #expect(throws: ToolExecutionError.self) {
            _ = try await tool.execute(arguments: [
                "url": ToolArgument("https://files.example.com/report.bin"),
                "filename": ToolArgument(outside.path),
                "directory": ToolArgument(downloadDirectory.path),
            ])
        }
        #expect(store.fetchAll().isEmpty)
        #expect(!FileManager.default.fileExists(atPath: outside.path))
    }

    @Test("已有文件不被静默覆盖")
    func existingFileIsNotOverwritten() async throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let downloadDirectory = root.appendingPathComponent("downloads", isDirectory: true)
        try FileManager.default.createDirectory(at: downloadDirectory, withIntermediateDirectories: true)
        let target = downloadDirectory.appendingPathComponent("target.bin")
        try Data("original".utf8).write(to: target)

        let tool = makeTool(store: store, download: { request in
            (Data("new".utf8), Self.httpResponse(url: request.url!, status: 200))
        })

        await #expect(throws: ToolExecutionError.self) {
            _ = try await tool.execute(arguments: [
                "url": ToolArgument("https://files.example.com/target.bin"),
                "filename": ToolArgument("target.bin"),
                "directory": ToolArgument(downloadDirectory.path),
            ])
        }
        let preserved = try Data(contentsOf: target)
        #expect(preserved == Data("original".utf8), "已有文件内容必须保持不变")
        #expect(store.fetchAll().isEmpty, "覆盖检查应在发起下载前完成")
    }

    @Test("普通文件名仍正常下载（防止过度拒绝）")
    func plainFilenameStillDownloads() async throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let downloadDirectory = root.appendingPathComponent("downloads", isDirectory: true)
        try FileManager.default.createDirectory(at: downloadDirectory, withIntermediateDirectories: true)

        let tool = makeTool(store: store, download: { request in
            (Data("payload".utf8), Self.httpResponse(url: request.url!, status: 200))
        })

        let result = try await tool.execute(arguments: [
            "url": ToolArgument("https://files.example.com/ok.bin"),
            "filename": ToolArgument("ok.bin"),
            "directory": ToolArgument(downloadDirectory.path),
        ])
        #expect(result.contains("下载完成"))
        let written = try Data(contentsOf: downloadDirectory.appendingPathComponent("ok.bin"))
        #expect(written == Data("payload".utf8))
        #expect(store.fetchAll().count == 1)
    }
}