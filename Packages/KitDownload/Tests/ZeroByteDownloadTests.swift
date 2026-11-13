import KitDownload
import Testing
import Foundation

/// 回归 #159：服务器成功返回零字节文件（200 + Content-Length: 0 + 空 body）时，
/// 下载任务必须进入 `.completed`，而不是被 FileValidator 一律判为 `.failed(.emptyFile)`。
///
/// 生产通用下载工具 `PluginDownload` 建任务时传 `expectedSize: nil`，MLX 路径传
/// `file.size`（可能为 0）。两种情形都必须放行合法空文件。这里复用
/// `DownloadManagerTests.MockHTTPClient`，以 `.success(Data())` 模拟空 body 下载，
/// 走完整 DownloadManager → FileValidator 链路。
@Suite("ZeroByteDownload Tests")
struct ZeroByteDownloadTests {

    private func withTempDir(_ body: (URL) async throws -> Void) async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ZeroByteDownloadTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        try await body(tempDir)
    }

    @Test("expectedSize 为 nil 的零字节下载必须进入完成态，不得误判失败")
    func zeroByteDownloadWithNilExpectedSizeCompletes() async throws {
        try await withTempDir { tempDir in
            let mockClient = MockHTTPClient()
            mockClient.downloadResult = .success(Data())
            let config = DownloadManager.Configuration(downloadDirectory: tempDir)
            let manager = DownloadManager(configuration: config, httpClient: mockClient)

            let destination = tempDir.appendingPathComponent("empty.txt")
            let task = DownloadTask(
                url: URL(string: "https://example.com/empty.txt")!,
                destination: destination,
                expectedSize: nil
            )

            let result = try await manager.download(task)

            #expect(result == destination)
            #expect(FileManager.default.fileExists(atPath: destination.path))
            let size = (try? FileManager.default.attributesOfItem(atPath: destination.path)[.size] as? Int64) ?? nil
            #expect(size == 0)
        }
    }

    @Test("expectedSize 为 0 的零字节下载必须进入完成态，不得误判失败")
    func zeroByteDownloadWithZeroExpectedSizeCompletes() async throws {
        try await withTempDir { tempDir in
            let mockClient = MockHTTPClient()
            mockClient.downloadResult = .success(Data())
            let config = DownloadManager.Configuration(downloadDirectory: tempDir)
            let manager = DownloadManager(configuration: config, httpClient: mockClient)

            let destination = tempDir.appendingPathComponent("empty.txt")
            let task = DownloadTask(
                url: URL(string: "https://example.com/empty.txt")!,
                destination: destination,
                expectedSize: 0
            )

            let result = try await manager.download(task)

            #expect(result == destination)
            #expect(FileManager.default.fileExists(atPath: destination.path))
        }
    }
}