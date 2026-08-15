import Foundation
import Testing
@testable import DownloadKit

private final class Box<T>: @unchecked Sendable { var value: T; init(_ v: T) { value = v } }

/// URLProtocol 桩：拦截 DefaultHTTPClient 的 URLSession 请求，不发真实网络
final class DownloadStubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        let (response, data) = handler(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        // 分块投递以驱动流式写入路径
        let chunk = 16
        var offset = data.startIndex
        while offset < data.endIndex {
            let end = data.index(offset, offsetBy: chunk, limitedBy: data.endIndex) ?? data.endIndex
            client?.urlProtocol(self, didLoad: data.subdata(in: offset..<end))
            offset = end
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

@Suite("DefaultHTTPClient", .serialized)
struct DefaultHTTPClientTests {
    private func makeClient() -> DefaultHTTPClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [DownloadStubURLProtocol.self]
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

    private func tempFile() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".bin")
        FileManager.default.createFile(atPath: url.path, contents: nil)
        return url
    }

    @Test func freshDownloadWritesEntireBody() async throws {
        let url = URL(string: "https://example.com/file.bin")!
        let dest = tempFile()
        defer { try? FileManager.default.removeItem(at: dest) }
        let body = Data((0..<100).map { UInt8($0 % 251) })
        let capturedRange = Box<String?>(nil)
        DownloadStubURLProtocol.handler = { request in
            capturedRange.value = request.value(forHTTPHeaderField: "Range")
            return self.respond(
                status: 200, headers: ["Content-Length": String(body.count)], body: body
            )
        }

        let totals = Box<[Int64?]>([])
        let written = try await makeClient().download(
            from: url, to: dest, existingBytes: 0, maxBytesPerSecond: nil,
            progressHandler: { _, total in totals.value.append(total) },
            onCancelled: { _ in }
        )
        #expect(written == 100)
        #expect(capturedRange.value == nil)
        #expect(try Data(contentsOf: dest) == body)
        #expect(totals.value.allSatisfy { $0 == 100 })
    }

    @Test func nonSuccessStatusThrowsWithoutWritingFile() async throws {
        let url = URL(string: "https://example.com/file.bin")!
        let dest = tempFile()
        defer { try? FileManager.default.removeItem(at: dest) }
        DownloadStubURLProtocol.handler = { _ in
            self.respond(status: 404, body: Data("<html>not found</html>".utf8))
        }

        await #expect(throws: DownloadError.httpError(404)) {
            _ = try await makeClient().download(
                from: url, to: dest, existingBytes: 0, maxBytesPerSecond: nil,
                progressHandler: { _, _ in }, onCancelled: { _ in }
            )
        }
        #expect((try? Data(contentsOf: dest))?.isEmpty != false)
    }

    @Test func resumeAppendsWithRangeRequest() async throws {
        let url = URL(string: "https://example.com/file.bin")!
        let dest = tempFile()
        defer { try? FileManager.default.removeItem(at: dest) }
        let prefix = Data(repeating: 0xAA, count: 400)
        try prefix.write(to: dest)
        let remainder = Data(repeating: 0xBB, count: 600)
        let capturedRange = Box<String?>(nil)
        DownloadStubURLProtocol.handler = { request in
            capturedRange.value = request.value(forHTTPHeaderField: "Range")
            return self.respond(
                status: 206,
                headers: ["Content-Range": "bytes 400-999/1000"],
                body: remainder
            )
        }

        let lastDownloaded = Box<Int64>(0)
        let lastTotal = Box<Int64?>(nil)
        let written = try await makeClient().download(
            from: url, to: dest, existingBytes: 400, maxBytesPerSecond: nil,
            progressHandler: { downloaded, total in
                lastDownloaded.value = downloaded; lastTotal.value = total
            },
            onCancelled: { _ in }
        )
        #expect(capturedRange.value == "bytes=400-")
        #expect(written == 600)
        #expect(lastDownloaded.value == 1000)
        #expect(lastTotal.value == 1000)
        let result = try Data(contentsOf: dest)
        #expect(result.count == 1000)
        #expect(result[..<400] == prefix)
        #expect(result[400...] == remainder)
    }

    @Test func serverIgnoringRangeRestartsFromScratch() async throws {
        let url = URL(string: "https://example.com/file.bin")!
        let dest = tempFile()
        defer { try? FileManager.default.removeItem(at: dest) }
        try Data(repeating: 0xAA, count: 400).write(to: dest)
        let full = Data(repeating: 0xCC, count: 1000)
        DownloadStubURLProtocol.handler = { _ in
            self.respond(status: 200, headers: ["Content-Length": "1000"], body: full)
        }

        let written = try await makeClient().download(
            from: url, to: dest, existingBytes: 400, maxBytesPerSecond: nil,
            progressHandler: { _, _ in }, onCancelled: { _ in }
        )
        #expect(written == 1000)
        #expect(try Data(contentsOf: dest) == full)
    }

    @Test func customHeadersReachServerRequest() async throws {
        let url = URL(string: "https://example.com/file.bin")!
        let dest = tempFile()
        defer { try? FileManager.default.removeItem(at: dest) }
        let body = Data("auth body".utf8)
        let capturedAuth = Box<String?>(nil)
        DownloadStubURLProtocol.handler = { request in
            capturedAuth.value = request.value(forHTTPHeaderField: "Authorization")
            return self.respond(
                status: 200, headers: ["Content-Length": String(body.count)], body: body
            )
        }

        let written = try await makeClient().download(
            from: url, to: dest, existingBytes: 0, maxBytesPerSecond: nil,
            headers: ["Authorization": "Bearer secret-token"],
            progressHandler: { _, _ in }, onCancelled: { _ in }
        )
        #expect(written == Int64(body.count))
        #expect(capturedAuth.value == "Bearer secret-token")
    }

    @Test func largeBodyStreamsThroughBufferedWrites() async throws {
        let url = URL(string: "https://example.com/large.bin")!
        let dest = tempFile()
        defer { try? FileManager.default.removeItem(at: dest) }
        // 大于 64KB 写缓冲：驱动流式分批写入路径（而非仅残余 flush）
        let body = Data((0..<200_000).map { UInt8($0 % 251) })
        DownloadStubURLProtocol.handler = { _ in
            self.respond(
                status: 200, headers: ["Content-Length": String(body.count)], body: body
            )
        }

        let written = try await makeClient().download(
            from: url, to: dest, existingBytes: 0, maxBytesPerSecond: nil,
            progressHandler: { _, _ in }, onCancelled: { _ in }
        )
        #expect(written == Int64(body.count))
        #expect(try Data(contentsOf: dest) == body)
    }

    @Test func resumeWithContentLengthOnlyReportsCumulativeTotal() async throws {
        let url = URL(string: "https://example.com/file.bin")!
        let dest = tempFile()
        defer { try? FileManager.default.removeItem(at: dest) }
        // 服务器 206 但只给 Content-Length（无 Content-Range）：total 应回退为
        // existingBytes + 本次长度，进度累计值正确
        try Data(repeating: 0xAA, count: 400).write(to: dest)
        let remainder = Data(repeating: 0xBB, count: 600)
        DownloadStubURLProtocol.handler = { _ in
            self.respond(
                status: 206,
                headers: ["Content-Length": String(remainder.count)],
                body: remainder
            )
        }

        let totals = Box<[Int64?]>([])
        let written = try await makeClient().download(
            from: url, to: dest, existingBytes: 400, maxBytesPerSecond: nil,
            progressHandler: { _, total in totals.value.append(total) },
            onCancelled: { _ in }
        )
        #expect(written == 600)
        #expect(totals.value.allSatisfy { $0 == 1000 })
        #expect(try Data(contentsOf: dest).count == 1000)
    }
}

/// 仅实现无请求头要求的极简 conformer：验证协议扩展对 download(...:headers:) 的
/// 默认实现（丢弃请求头、退回无请求头版本）仍能正常下载。
private struct HeaderAgnosticClient: HTTPClient {
    func download(
        from url: URL,
        to destination: URL,
        existingBytes: Int64,
        maxBytesPerSecond: Int?,
        progressHandler: @Sendable @escaping (Int64, Int64?) -> Void,
        onCancelled: @Sendable @escaping (Data?) -> Void
    ) async throws -> Int64? {
        let data = Data("plain".utf8)
        try data.write(to: destination)
        progressHandler(Int64(data.count), Int64(data.count))
        return Int64(data.count)
    }
}

extension DefaultHTTPClientTests {
    @Test func defaultHeadersImplementationFallsBackGracefully() async throws {
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".bin")
        defer { try? FileManager.default.removeItem(at: dest) }

        let client: any HTTPClient = HeaderAgnosticClient()
        let written = try await client.download(
            from: URL(string: "https://example.com/plain.bin")!,
            to: dest,
            existingBytes: 0,
            maxBytesPerSecond: nil,
            headers: ["Authorization": "Bearer ignored"],
            progressHandler: { _, _ in },
            onCancelled: { _ in }
        )
        #expect(written == 5)
        #expect(try Data(contentsOf: dest) == Data("plain".utf8))
    }
}
