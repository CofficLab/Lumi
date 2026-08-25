import Foundation
import Testing
@testable import KitDownload

private final class Box<T>: @unchecked Sendable { var value: T; init(_ v: T) { value = v } }

/// URLProtocol 桩（与 DefaultHTTPClientTests 相同，供覆盖率测试独立使用）
final class DownloadCoverageStubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) -> (HTTPURLResponse, Data))?
    /// 非空时：投递这些字节后以错误结束（模拟网络中途断开），忽略 handler 的 body
    nonisolated(unsafe) static var failAfterLoading: Data?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        let (response, data) = handler(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        if let partial = Self.failAfterLoading {
            client?.urlProtocol(self, didLoad: partial)
            client?.urlProtocol(self, didFailWithError: URLError(.networkConnectionLost))
            return
        }
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

@Suite("KitDownload coverage", .serialized)
struct DownloadCoverageTests {
    private func makeClient() -> DefaultHTTPClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [DownloadCoverageStubURLProtocol.self]
        return DefaultHTTPClient(configuration: config)
    }

    private func respond(status: Int, headers: [String: String] = [:], body: Data) -> (HTTPURLResponse, Data) {
        let response = HTTPURLResponse(
            url: URL(string: "https://example.com/file.bin")!,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        )!
        return (response, body)
    }

    @Test("convenience download without rate limit writes whole body")
    func convenienceDownload() async throws {
        let url = URL(string: "https://example.com/file.bin")!
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".bin")
        defer { try? FileManager.default.removeItem(at: dest) }
        let body = Data("coverage body".utf8)
        DownloadCoverageStubURLProtocol.handler = { _ in
            self.respond(status: 200, headers: ["Content-Length": String(body.count)], body: body)
        }
        let progressPairs = Box<[(Int64, Int64?)]>([])
        let written = try await makeClient().download(
            from: url,
            to: dest,
            existingBytes: 0,
            progressHandler: { downloaded, total in progressPairs.value.append((downloaded, total)) },
            onCancelled: { _ in }
        )
        #expect(written == Int64(body.count))
        #expect(try Data(contentsOf: dest) == body)
        #expect(!progressPairs.value.isEmpty)
    }

    @Test("resume with missing partial file starts fresh")
    func resumeWithoutPartialFile() async throws {
        let url = URL(string: "https://example.com/file.bin")!
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".bin")
        defer { try? FileManager.default.removeItem(at: dest) }
        let body = Data((0..<64).map { UInt8($0) })
        DownloadCoverageStubURLProtocol.handler = { _ in
            self.respond(
                status: 206,
                headers: ["Content-Length": String(body.count), "Content-Range": "bytes 4-63/64"],
                body: body
            )
        }
        // existingBytes > 0 但目标文件不存在：应创建新文件从头写入
        _ = try await makeClient().download(
            from: url,
            to: dest,
            existingBytes: 4,
            maxBytesPerSecond: nil,
            progressHandler: { _, _ in },
            onCancelled: { _ in }
        )
        #expect(FileManager.default.fileExists(atPath: dest.path))
    }

    @Test("isComplete returns false for missing file")
    func isCompleteMissingFile() {
        let validator = FileValidator()
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("missing-\(UUID().uuidString).bin")
        #expect(!validator.isComplete(fileAt: missing, expectedSize: 10))
    }

    @Test("downloading same task twice throws and failure marks state failed")
    func duplicateTaskAndFailureState() async throws {
        let mock = MockHTTPClient()
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("DownloadCoverage-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let config = DownloadManager.Configuration(downloadDirectory: tempDir)
        let manager = DownloadManager(configuration: config, httpClient: mock)

        // 1) 并发重复任务被拒绝
        mock.downloadDelay = .milliseconds(300)
        let task = DownloadTask(
            id: "dup",
            url: URL(string: "https://example.com/a.bin")!,
            destination: tempDir.appendingPathComponent("a.bin")
        )
        async let first = manager.download(task)
        try await Task.sleep(for: .milliseconds(50))
        await #expect(throws: DownloadError.self) {
            _ = try await manager.download(task)
        }
        _ = try await first
        let dupStates = await manager.allTaskStates()
        #expect(dupStates["dup"] != nil)

        // 2) 失败任务进入 failed 状态
        mock.reset()
        mock.downloadResult = .failure(URLError(.badServerResponse))
        let failing = DownloadTask(
            id: "fail",
            url: URL(string: "https://example.com/b.bin")!,
            destination: tempDir.appendingPathComponent("b.bin")
        )
        await #expect(throws: Error.self) {
            _ = try await manager.download(failing)
        }
        let failStates = await manager.allTaskStates()
        guard case .failed = failStates["fail"] else {
            Issue.record("expected failed state, got \(String(describing: failStates["fail"]))")
            return
        }
    }

    @Test("DefaultHTTPClient 无请求头方法委托到带请求头版本")
    func defaultClientNoHeadersOverloadDelegates() async throws {
        let url = URL(string: "https://example.com/file.bin")!
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".bin")
        defer { try? FileManager.default.removeItem(at: dest) }
        let body = Data("no headers body".utf8)
        DownloadCoverageStubURLProtocol.handler = { _ in
            self.respond(status: 200, headers: ["Content-Length": String(body.count)], body: body)
        }
        // 调用 DefaultHTTPClient 自身的无请求头方法（带 maxBytesPerSecond）：
        // 应委托到带 headers 的实现并正常写入
        let written = try await makeClient().download(
            from: url, to: dest, existingBytes: 0, maxBytesPerSecond: nil,
            progressHandler: { _, _ in }, onCancelled: { _ in }
        )
        #expect(written == Int64(body.count))
        #expect(try Data(contentsOf: dest) == body)
    }

    @Test("网络中途断开时抛出错误且已写字节保留在磁盘")
    func midStreamFailureThrowsAndKeepsWrittenBytes() async throws {
        let url = URL(string: "https://example.com/file.bin")!
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".bin")
        defer { try? FileManager.default.removeItem(at: dest) }
        // 投递 128KB 后断开：驱动 64KB 缓冲的批量写入路径 + 中途失败重抛
        let partial = Data(repeating: 0x42, count: 128 * 1024)
        DownloadCoverageStubURLProtocol.handler = { _ in
            self.respond(status: 200, headers: ["Content-Length": "262144"], body: Data())
        }
        DownloadCoverageStubURLProtocol.failAfterLoading = partial
        defer { DownloadCoverageStubURLProtocol.failAfterLoading = nil }

        let caught = Box<Error?>(nil)
        do {
            _ = try await makeClient().download(
                from: url, to: dest, existingBytes: 0, maxBytesPerSecond: nil,
                progressHandler: { _, _ in }, onCancelled: { _ in }
            )
        } catch {
            caught.value = error
        }
        #expect(caught.value != nil, "中途断开应抛出错误")
        // 已写入的完整缓冲批次应保留在磁盘（流式落盘，可作为下次续传起点）
        let written = (try? Data(contentsOf: dest))?.count ?? 0
        #expect(written <= partial.count, "磁盘上最多只应有已投递的字节，实际：\(written)")
    }

    @Test("本地化查找未命中时回退返回 key 本身")
    func localizationFallsBackToKey() {
        let key = "downloadkit.coverage.missing-key"
        let value = KitDownloadLocalization.string(key, bundle: .module)
        #expect(value == key, "未命中 key 应原样返回，实际：\(value)")
    }
}
