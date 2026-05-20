import Foundation
import HttpKit

/// 提供 GitHub Token 的对象。
public protocol GitHubTokenProviding: Sendable {
    /// 当前可用的 GitHub access token。
    var accessToken: String? { get }
}

/// GitHub REST API 客户端。
public final class GitHubAPIService: @unchecked Sendable {
    /// 共享客户端实例。
    public static let shared = GitHubAPIService()

    /// API 基础 URL。
    private let baseURL: String

    /// HTTP 客户端。
    private let client: HTTPClient

    /// 可选 token provider。由上层插件注入，避免 package 依赖插件设置存储。
    private var tokenProvider: GitHubTokenProviding?

    /// 创建 GitHub API 客户端。
    ///
    /// - Parameters:
    ///   - baseURL: GitHub API 基础 URL。
    ///   - tokenProvider: 可选 token provider。
    public init(
        baseURL: String = "https://api.github.com",
        tokenProvider: GitHubTokenProviding? = nil
    ) {
        self.baseURL = baseURL
        self.tokenProvider = tokenProvider
        self.client = HTTPClient { config in
            config.httpAdditionalHeaders = [
                "Accept": "application/vnd.github.v3+json",
                "User-Agent": "Lumi-GitHub-Plugin/1.0",
            ]
        }
    }

    /// 更新共享客户端使用的 token provider。
    public func setTokenProvider(_ tokenProvider: GitHubTokenProviding?) {
        self.tokenProvider = tokenProvider
    }

    /// 获取仓库信息。
    public func getRepoInfo(owner: String, repo: String) async throws -> GitHubRepository {
        try await fetch("/repos/\(owner)/\(repo)")
    }

    /// 搜索仓库。
    public func searchRepositories(
        query: String,
        page: Int = 1,
        perPage: Int = 10,
        sort: String? = nil,
        order: String? = nil
    ) async throws -> GitHubSearchResult {
        return try await fetch(
            "/search/repositories",
            params: searchRepositoryParameters(
                query: query,
                page: page,
                perPage: perPage,
                sort: sort,
                order: order
            )
        ) as GitHubSearchResult
    }

    /// 获取文件内容。
    public func getFileContent(
        owner: String,
        repo: String,
        path: String,
        branch: String = "main"
    ) async throws -> GitHubFileContent {
        try await fetch(
            "/repos/\(owner)/\(repo)/contents/\(path)",
            params: ["ref": branch]
        )
    }

    /// 获取趋势项目。当前通过仓库搜索模拟。
    public func getTrendingRepositories(since: String = "daily") async throws -> [GitHubRepository] {
        let query = "stars:>1000"
        let sort: String
        switch since.lowercased() {
        case "weekly": sort = "updated"
        case "monthly": sort = "stars"
        default: sort = "stars"
        }
        let result: GitHubSearchResult = try await fetch(
            "/search/repositories",
            params: ["q": query, "sort": sort, "order": "desc"]
        )
        return result.items
    }

    /// 获取仓库 Issue 列表。
    public func getIssues(
        owner: String,
        repo: String,
        state: GitHubIssueState = .open,
        page: Int = 1,
        perPage: Int = 10
    ) async throws -> [GitHubIssue] {
        try await fetch(
            "/repos/\(owner)/\(repo)/issues",
            params: [
                "state": state.rawValue,
                "page": "\(page)",
                "per_page": "\(perPage)",
                "filter": "all",
            ]
        )
    }

    /// 获取 Issue 详情。
    public func getIssue(
        owner: String,
        repo: String,
        issueNumber: Int
    ) async throws -> GitHubIssue {
        try await fetch("/repos/\(owner)/\(repo)/issues/\(issueNumber)")
    }

    /// 创建 Issue。
    public func createIssue(
        owner: String,
        repo: String,
        title: String,
        body: String? = nil,
        labels: [String]? = nil,
        assignees: [String]? = nil,
        milestone: Int? = nil
    ) async throws -> GitHubIssue {
        let request = CreateIssueRequest(
            title: title,
            body: body,
            labels: labels,
            assignees: assignees,
            milestone: milestone
        )
        return try await post("/repos/\(owner)/\(repo)/issues", body: request)
    }

    /// 更新 Issue。
    public func updateIssue(
        owner: String,
        repo: String,
        issueNumber: Int,
        title: String? = nil,
        body: String? = nil,
        state: String? = nil,
        labels: [String]? = nil,
        assignees: [String]? = nil,
        milestone: Int? = nil
    ) async throws -> GitHubIssue {
        let request = UpdateIssueRequest(
            title: title,
            body: body,
            state: state,
            labels: labels,
            assignees: assignees,
            milestone: milestone
        )
        return try await patch("/repos/\(owner)/\(repo)/issues/\(issueNumber)", body: request)
    }

    /// 关闭 Issue。
    public func closeIssue(
        owner: String,
        repo: String,
        issueNumber: Int
    ) async throws -> GitHubIssue {
        try await updateIssue(owner: owner, repo: repo, issueNumber: issueNumber, state: "closed")
    }

    /// 重新打开 Issue。
    public func reopenIssue(
        owner: String,
        repo: String,
        issueNumber: Int
    ) async throws -> GitHubIssue {
        try await updateIssue(owner: owner, repo: repo, issueNumber: issueNumber, state: "open")
    }

    /// 获取 Issue 评论列表。
    public func getIssueComments(
        owner: String,
        repo: String,
        issueNumber: Int,
        page: Int = 1,
        perPage: Int = 10
    ) async throws -> [GitHubIssueComment] {
        try await fetch(
            "/repos/\(owner)/\(repo)/issues/\(issueNumber)/comments",
            params: [
                "page": "\(page)",
                "per_page": "\(perPage)",
            ]
        )
    }

    /// 添加 Issue 评论。
    public func addIssueComment(
        owner: String,
        repo: String,
        issueNumber: Int,
        body: String
    ) async throws -> GitHubIssueComment {
        let request = CreateIssueCommentRequest(body: body)
        return try await post("/repos/\(owner)/\(repo)/issues/\(issueNumber)/comments", body: request)
    }

    /// 构建 GET URLRequest。
    private func buildGetRequest(endpoint: String, params: [String: String] = [:]) -> URLRequest {
        var components = URLComponents(string: baseURL + endpoint)!
        if !params.isEmpty {
            components.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        applyAuth(request: &request)
        return request
    }

    /// 构建仓库搜索请求参数，保持空排序参数不会进入 URL。
    func searchRepositoryParameters(
        query: String,
        page: Int,
        perPage: Int,
        sort: String?,
        order: String?
    ) -> [String: String] {
        var params = [
            "q": query,
            "page": "\(page)",
            "per_page": "\(perPage)",
        ]
        if let sort, !sort.isEmpty {
            params["sort"] = sort
        }
        if let order, !order.isEmpty {
            params["order"] = order
        }
        return params
    }

    /// 构建带 body 的 URLRequest。
    private func buildBodyRequest(endpoint: String, method: String) -> URLRequest {
        let url = URL(string: baseURL + endpoint)!
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuth(request: &request)
        return request
    }

    /// 应用认证头。
    private func applyAuth(request: inout URLRequest) {
        if let token = tokenProvider?.accessToken, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }

    /// 将 HttpKit 错误映射为 GitHubAPIError。
    private func mapError(_ error: HTTPClientError) -> GitHubAPIError {
        if case let .httpError(statusCode, _) = error {
            switch statusCode {
            case 401, 403: return .unauthorized
            case 404: return .httpError(404)
            case 429: return .rateLimited
            default: return .httpError(statusCode)
            }
        }
        return .networkError(error)
    }

    /// 发送 GET 请求并自动解码。
    private func fetch<T: Decodable>(
        _ endpoint: String,
        params: [String: String] = [:]
    ) async throws -> T {
        let request = buildGetRequest(endpoint: endpoint, params: params)

        do {
            return try await client.sendDecodableRequest(request: request, as: T.self)
        } catch let error as HTTPClientError {
            throw mapError(error)
        } catch let error as DecodingError {
            throw GitHubAPIError.decodeError(error)
        } catch {
            throw GitHubAPIError.networkError(error)
        }
    }

    /// 发送 POST 请求并自动解码。
    private func post<T: Decodable, B: Encodable>(
        _ endpoint: String,
        body: B
    ) async throws -> T {
        let request = buildBodyRequest(endpoint: endpoint, method: "POST")

        do {
            let data = try await client.sendEncodableRequest(request: request, body: body)
            return try JSONDecoder().decode(T.self, from: data)
        } catch let error as HTTPClientError {
            throw mapError(error)
        } catch let error as DecodingError {
            throw GitHubAPIError.decodeError(error)
        } catch {
            throw GitHubAPIError.networkError(error)
        }
    }

    /// 发送 PATCH 请求并自动解码。
    private func patch<T: Decodable, B: Encodable>(
        _ endpoint: String,
        body: B
    ) async throws -> T {
        let request = buildBodyRequest(endpoint: endpoint, method: "PATCH")

        do {
            let data = try await client.sendEncodableRequest(request: request, body: body)
            return try JSONDecoder().decode(T.self, from: data)
        } catch let error as HTTPClientError {
            throw mapError(error)
        } catch let error as DecodingError {
            throw GitHubAPIError.decodeError(error)
        } catch {
            throw GitHubAPIError.networkError(error)
        }
    }
}
