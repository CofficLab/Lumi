import Foundation
import ProviderNetwork
import Testing
@testable import PluginNetworkManager

/// 防回归测试：「URLSession 自动跟随重定向后，`request` 返回的
/// `HTTPResponse.url` 必须是最终响应 URL，而不是原始请求 URL」（#192）。
///
/// ## 历史 bug
///
/// `NetworkProvider.request` 曾用 `request.url` 回填 `HTTPResponse.url`。
/// WebFetch 经 `KernelWebFetchFetcher` 用该 URL 构造 `HTTPURLResponse`，
/// 再以它为基准解析 HTML 相对链接，导致重定向后的页面链接全部解析到
/// 重定向前的错误目录。
struct NetworkProviderRedirectURLTests {

    /// URLProtocol 桩：`/start` 返回 302 → `/docs/index.html` 返回 200。
    private final class RedirectingURLProtocol: URLProtocol {
        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

        override func startLoading() {
            guard let url = request.url else {
                client?.urlProtocol(self, didFailWithError: URLError(.badURL))
                return
            }

            if url.path == "/start" {
                let redirectURL = URL(string: "https://redirect.invalid/docs/index.html")!
                let redirectRequest = URLRequest(url: redirectURL)
                let response = HTTPURLResponse(
                    url: url,
                    statusCode: 302,
                    httpVersion: "HTTP/1.1",
                    headerFields: ["Location": redirectURL.absoluteString]
                )!
                client?.urlProtocol(self, wasRedirectedTo: redirectRequest, redirectResponse: response)
                return
            }

            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "text/html"]
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data("<html><body>final</body></html>".utf8))
            client?.urlProtocolDidFinishLoading(self)
        }

        override func stopLoading() {}
    }

    @Test
    func requestReturnsFinalURLAfterRedirect() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RedirectingURLProtocol.self]
        let provider = NetworkProvider(session: URLSession(configuration: configuration))

        let response = try await provider.request(
            HTTPRequest(url: URL(string: "https://redirect.invalid/start")!)
        )

        #expect(response.statusCode == 200)
        #expect(response.url == URL(string: "https://redirect.invalid/docs/index.html"))
    }
}