import Foundation
import Testing
@testable import ProviderNetwork

/// NetworkProviding 协议与 HTTP 类型的基础验证。
///
/// 请求用 `MockURLProtocol` 拦截（注入 `URLSessionConfiguration`），
/// 完全本地可控、无网络依赖。
@Suite("ProviderNetwork", .serialized)
struct ProviderNetworkTests {

    /// 拦截 URLSession 请求并返回预置响应的 URLProtocol。
    private final class MockURLProtocol: URLProtocol {
        nonisolated(unsafe) static var handler: (@Sendable (URLRequest) throws -> (Int, [String: String], Data))?

        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

        override func startLoading() {
            guard let handler = Self.handler else {
                client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
                return
            }
            do {
                let (status, headers, body) = try handler(request)
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: status,
                    httpVersion: "HTTP/1.1",
                    headerFields: headers
                )!
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: body)
                client?.urlProtocolDidFinishLoading(self)
            } catch {
                client?.urlProtocol(self, didFailWithError: error)
            }
        }

        override func stopLoading() {}
    }

    /// 用 mock 配置创建 ProviderNetwork 默认实现。
    private func makeProvider() -> DefaultNetworkProviding {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return DefaultNetworkProviding(configuration: config)
    }

    @Test("HTTP 类型值语义与便捷属性")
    func httpTypesBasics() throws {
        let request = HTTPRequest(url: URL(string: "https://example.com")!, method: .post, headers: ["a": "b"])
        #expect(request.method == .post)
        #expect(request.headers["a"] == "b")

        let response = HTTPResponse(statusCode: 200, headers: [:], body: Data("ok".utf8), url: request.url)
        #expect(response.isSuccess)
        #expect(response.bodyString == "ok")

        let error = HTTPNetworkError(url: request.url, statusCode: 404)
        #expect(error.errorDescription?.contains("404") == true)
    }

    @Test("get 请求返回 mock 响应")
    func getReturnsMockResponse() async throws {
        MockURLProtocol.handler = { request in
            #expect(request.url?.path == "/hi")
            return (200, ["Content-Type": "application/json"], Data(#"{"hello":"world"}"#.utf8))
        }

        let provider = makeProvider()
        let response = try await provider.get(url: URL(string: "https://mock.local/hi")!)

        #expect(response.statusCode == 200)
        #expect(response.bodyString?.contains("world") == true)
    }

    @Test("json 请求自动编解码")
    func jsonEncodesAndDecodes() async throws {
        struct Echo: Codable, Sendable { let value: Int }

        MockURLProtocol.handler = { request in
            // 默认 json 实现应设置 Content-Type 与 Accept
            #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
            #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
            return (200, ["Content-Type": "application/json"], Data(#"{"value":42}"#.utf8))
        }

        let provider = makeProvider()
        let result: Echo = try await provider.json(
            url: URL(string: "https://mock.local/echo")!,
            method: .post,
            body: Echo(value: 1)
        )

        #expect(result.value == 42)
    }

    @Test("stream 收到响应头与字节块")
    func streamDeliversMetadataAndChunks() async throws {
        MockURLProtocol.handler = { _ in
            (200, ["Content-Type": "text/plain"], Data("abc".utf8))
        }

        let provider = makeProvider()

        // @Sendable 闭包内不能捕获并修改局部 var，用引用类型收集状态。
        final class Collector: @unchecked Sendable {
            var metadata: HTTPResponseMetadata?
            var text = ""
        }
        let collector = Collector()

        try await provider.stream(
            HTTPRequest(url: URL(string: "https://mock.local/stream")!, timeout: 5),
            onResponse: { metadata in
                collector.metadata = metadata
            },
            onChunk: { data in
                collector.text += String(data: data, encoding: .utf8) ?? ""
                return true
            }
        )

        #expect(collector.metadata?.statusCode == 200)
        #expect(collector.text == "abc")
    }

    @Test("DefaultNetworkProviding 可作为 any NetworkProviding 使用")
    func providerAccessibleThroughProtocol() {
        let provider: any NetworkProviding = makeProvider()
        // 协议存在类型可正常构造即可；具体请求行为已由上面用例覆盖。
        _ = provider
    }
}
