import Foundation
import Testing
@testable import GitHubKit

private struct StubTokenProvider: GitHubTokenProviding {
    let token: String?
    var accessToken: String? { token }
}

@Suite("GitHubAPIService request building")
struct GitHubRequestBuildingTests {
    @Test("GET 请求带查询参数且方法正确")
    func getRequestIncludesQueryParameters() throws {
        let service = GitHubAPIService(baseURL: "https://api.github.com")
        let request = try service.buildGetRequest(
            endpoint: "/search/repositories",
            params: ["q": "lumi", "per_page": "10"]
        )
        #expect(request.httpMethod == "GET")
        let url = try #require(request.url)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let items = try #require(components.queryItems)
        #expect(items.contains(URLQueryItem(name: "q", value: "lumi")))
        #expect(items.contains(URLQueryItem(name: "per_page", value: "10")))
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
    }

    @Test("token provider 注入 Bearer 头")
    func tokenProviderAppliesBearerHeader() throws {
        let service = GitHubAPIService(
            baseURL: "https://api.github.com",
            tokenProvider: StubTokenProvider(token: "secret-token")
        )
        let request = try service.buildGetRequest(endpoint: "/repos/a/b")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer secret-token")
    }

    @Test("空 token 不注入认证头")
    func emptyTokenOmitsAuthorizationHeader() throws {
        let service = GitHubAPIService(
            baseURL: "https://api.github.com",
            tokenProvider: StubTokenProvider(token: "")
        )
        let request = try service.buildGetRequest(endpoint: "/repos/a/b")
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
    }

    @Test("非 http(s) scheme 抛出 invalidURL", arguments: ["ftp://api.github.com", "file:///tmp"])
    func nonHTTPSchemeIsRejected(baseURL: String) {
        let service = GitHubAPIService(baseURL: baseURL)
        #expect(throws: GitHubAPIError.self) {
            _ = try service.buildGetRequest(endpoint: "/repos/a/b")
        }
    }

    @Test("错误描述非空")
    func errorDescriptions() {
        let errors: [GitHubAPIError] = [
            .invalidURL("ftp://x"),
            .unauthorized,
            .rateLimited,
            .decodeError(DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "x"))),
            .networkError(URLError(.badURL)),
        ]
        for error in errors {
            #expect(!(error.errorDescription ?? "").isEmpty)
        }
    }
}
