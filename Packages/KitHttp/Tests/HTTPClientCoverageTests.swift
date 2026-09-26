import Foundation
import Testing
@testable import KitHttp

// MARK: - 独立的 mock 协议，handler 为独立静态状态，避免与既有 suite 并行时互相覆盖

private final class CoverageMockProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, [Data]))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            guard let handler = Self.handler else {
                client?.urlProtocol(self, didFailWithError: NSError(domain: "CoverageMock", code: -1))
                return
            }
            let (response, chunks) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            for chunk in chunks {
                client?.urlProtocol(self, didLoad: chunk)
            }
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

// MARK: - 补充覆盖：回调契约、头契约、错误路径、薄封装

@Suite("HTTPClient 补充覆盖", .serialized)
struct HTTPClientCoverageTests {

    private func makeClient() -> HTTPClient {
        HTTPClient.mockClient(protocols: [CoverageMockProtocol.self])
    }

    // MARK: - body 编码与响应解析

    @Test("sendJSONRequest 正确编码并解析响应")
    func sendJSONRequestEncodesBodyAndParsesResponse() async throws {
        // 注：URLProtocol 层拿不到 httpBody（URLSession 内部转为 stream），
        // 因此这里只验证往返：POST 到达 mock、200 响应被正确解析。
        CoverageMockProtocol.handler = { request in
            #expect(request.httpMethod == "POST")
            return (
                HTTPURLResponse(url: URL(string: "https://mock.test")!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!,
                [Data("{\"ok\":true}".utf8)]
            )
        }
        defer { CoverageMockProtocol.handler = nil }

        var request = URLRequest(url: URL(string: "https://mock.test/api")!)
        request.httpMethod = "POST"

        let (data, resp) = try await makeClient().sendJSONRequestWithResponse(request: request, body: ["q": "hello"])
        #expect(resp.statusCode == 200)
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Bool]
        #expect(obj?["ok"] == true)
    }

    // MARK: - onResponseReceived 回调契约

    @Test("sendStreamingJSONRequest 在 2xx 时回调 onResponseReceived")
    func streamingCallsOnResponseReceivedOnSuccess() async throws {
        CoverageMockProtocol.handler = { _ in
            (
                HTTPURLResponse(url: URL(string: "https://mock.test")!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["X-Req-Id": "abc"])!,
                [Data("data: ok\n\n".utf8)]
            )
        }
        defer { CoverageMockProtocol.handler = nil }

        var request = URLRequest(url: URL(string: "https://mock.test/stream")!)
        request.httpMethod = "POST"

        let received = Box<HTTPURLResponse?>(nil)
        try await makeClient().sendStreamingJSONRequest(
            request: request,
            body: ["q": "x"],
            onResponseReceived: { resp in received.value = resp },
            onEvent: { _ in true }
        )

        #expect(received.value?.statusCode == 200)
        #expect(received.value?.value(forHTTPHeaderField: "X-Req-Id") == "abc")
    }

    @Test("sendStreamingJSONRequest 在非 2xx 时仍回调 onResponseReceived")
    func streamingCallsOnResponseReceivedOnError() async {
        CoverageMockProtocol.handler = { _ in
            (
                HTTPURLResponse(url: URL(string: "https://mock.test")!, statusCode: 503, httpVersion: "HTTP/1.1", headerFields: nil)!,
                [Data("Service Unavailable".utf8)]
            )
        }
        defer { CoverageMockProtocol.handler = nil }

        var request = URLRequest(url: URL(string: "https://mock.test/stream")!)
        request.httpMethod = "POST"

        let received = Box<HTTPURLResponse?>(nil)
        do {
            try await makeClient().sendStreamingJSONRequest(
                request: request,
                body: [:],
                onResponseReceived: { resp in received.value = resp },
                onEvent: { _ in true }
            )
            Issue.record("期望 503 错误")
        } catch let error as HTTPClientError {
            guard case .httpError(503, _) = error else {
                Issue.record("期望 httpError(503)，实际 \(error)")
                return
            }
        } catch {
            Issue.record("意外错误: \(error)")
        }
        // onResponseReceived 在状态码检查之前触发，503 也应收到。
        #expect(received.value?.statusCode == 503)
    }

    // MARK: - 请求头契约

    @Test("流式请求自动带上 Accept: text/event-stream")
    func streamingSetsEventStreamAcceptHeader() async throws {
        CoverageMockProtocol.handler = { request in
            #expect(request.value(forHTTPHeaderField: "Accept") == "text/event-stream")
            return (
                HTTPURLResponse(url: URL(string: "https://mock.test")!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!,
                [Data("data: ok\n\n".utf8)]
            )
        }
        defer { CoverageMockProtocol.handler = nil }

        let request = URLRequest(url: URL(string: "https://mock.test/stream")!)
        try await makeClient().sendStreamingRequest(request: request) { _ in true }
    }

    // MARK: - 行级流式的网络错误路径

    @Test("sendStreamingRequest 行模式遇网络错误包装为 requestFailed")
    func streamingLineNetworkError() async {
        CoverageMockProtocol.handler = { _ in
            throw NSError(domain: NSURLErrorDomain, code: NSURLErrorCannotConnectToHost)
        }
        defer { CoverageMockProtocol.handler = nil }

        let request = URLRequest(url: URL(string: "https://mock.test/stream")!)
        do {
            try await makeClient().sendStreamingRequest(request: request) { _ in true }
            Issue.record("期望错误")
        } catch let error as HTTPClientError {
            guard case .requestFailed = error else {
                Issue.record("期望 requestFailed，实际 \(error)")
                return
            }
        } catch {
            Issue.record("意外错误: \(error)")
        }
    }

    // MARK: - 薄封装

    @Test("KitHttpLocalization 未命中时回退 key")
    func localizationFallbackToKey() {
        let bundle = Bundle(for: BundleFinder.self)
        let key = "kithttp.coverage.missing-key"
        #expect(KitHttpLocalization.string(key, bundle: bundle) == key)
    }
}

private final class BundleFinder {}
