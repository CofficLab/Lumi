import Foundation
import MagicKit

/// GitHub API 服务
///
/// 封装 GitHub REST API v3 的网络请求
final class GitHubAPIService: @unchecked Sendable, SuperLog {
    nonisolated static let emoji = "🐙"
    nonisolated static let verbose = true

    static let shared = GitHubAPIService()

    /// API 基础 URL
    private let baseURL = "https://api.github.com"

    /// URL 会话
    private let session: URLSession
    private let settingsStore = GitHubPluginLocalStore()
    private let tokenKey = "GitHubToken"

    /// GitHub Token（从插件设置读取）
    private var accessToken: String? {
        settingsStore.string(forKey: tokenKey)
    }

    private init() {
        settingsStore.migrateLegacyValueIfMissing(forKey: tokenKey)
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = [
            "Accept": "application/vnd.github.v3+json",
            "User-Agent": "Lumi-GitHub-Plugin/1.0"
        ]
        session = URLSession(configuration: config)
    }

    // MARK: - 公开方法

    /// 获取仓库信息
    /// - Parameters:
    ///   - owner: 仓库所有者
    ///   - repo: 仓库名称
    /// - Returns: GitHubRepository 对象
    func getRepoInfo(owner: String, repo: String) async throws -> GitHubRepository {
        let endpoint = "/repos/\(owner)/\(repo)"
        return try await fetch(endpoint)
    }

    /// 搜索仓库
    /// - Parameters:
    ///   - query: 搜索关键词
    ///   - page: 页码
    ///   - perPage: 每页数量
    /// - Returns: GitHubSearchResult 搜索结果
    func searchRepositories(
        query: String,
        page: Int = 1,
        perPage: Int = 10
    ) async throws -> GitHubSearchResult {
        let endpoint = "/search/repositories"
        let params = [
            "q": query,
            "page": "\(page)",
            "per_page": "\(perPage)"
        ]
        return try await fetch(endpoint, params: params)
    }

    /// 获取文件内容
    /// - Parameters:
    ///   - owner: 仓库所有者
    ///   - repo: 仓库名称
    ///   - path: 文件路径
    ///   - branch: 分支名称
    /// - Returns: GitHubFileContent 文件内容
    func getFileContent(
        owner: String,
        repo: String,
        path: String,
        branch: String = "main"
    ) async throws -> GitHubFileContent {
        let endpoint = "/repos/\(owner)/\(repo)/contents/\(path)"
        let params = ["ref": branch]
        return try await fetch(endpoint, params: params)
    }

    /// 获取趋势项目（通过搜索模拟）
    /// - Parameter since: 时间范围 (daily/weekly/monthly)
    /// - Returns: GitHubRepository 数组
    func getTrendingRepositories(since: String = "daily") async throws -> [GitHubRepository] {
        // GitHub API 无官方趋势接口，通过搜索高 star 项目模拟
        let query = "stars:>1000"
        let sort: String
        switch since.lowercased() {
        case "weekly":
            sort = "updated"
        case "monthly":
            sort = "stars"
        default:
            sort = "stars"
        }
        let result: GitHubSearchResult = try await fetch(
            "/search/repositories",
            params: ["q": query, "sort": sort, "order": "desc"]
        )
        return result.items
    }

    /// 获取仓库 Issue 列表
    /// - Parameters:
    ///   - owner: 仓库所有者
    ///   - repo: 仓库名称
    ///   - state: Issue 状态（open/closed/all）
    ///   - page: 页码
    ///   - perPage: 每页数量
    /// - Returns: GitHubIssue 数组
    func getIssues(
        owner: String,
        repo: String,
        state: GitHubIssueState = .open,
        page: Int = 1,
        perPage: Int = 10
    ) async throws -> [GitHubIssue] {
        let endpoint = "/repos/\(owner)/\(repo)/issues"
        var params: [String: String] = [
            "state": state.rawValue,
            "page": "\(page)",
            "per_page": "\(perPage)"
        ]
        // 排除 PR（PR 在 GitHub API 中也是 issue，通过 filter 排除）
        params["filter"] = "all"
        return try await fetch(endpoint, params: params)
    }

    /// 获取 Issue 详情
    /// - Parameters:
    ///   - owner: 仓库所有者
    ///   - repo: 仓库名称
    ///   - issueNumber: Issue 编号
    /// - Returns: GitHubIssue 对象
    func getIssue(
        owner: String,
        repo: String,
        issueNumber: Int
    ) async throws -> GitHubIssue {
        let endpoint = "/repos/\(owner)/\(repo)/issues/\(issueNumber)"
        return try await fetch(endpoint)
    }

    /// 创建 Issue
    /// - Parameters:
    ///   - owner: 仓库所有者
    ///   - repo: 仓库名称
    ///   - title: Issue 标题
    ///   - body: Issue 描述
    ///   - labels: 标签数组
    ///   - assignees: 指派的用户数组
    ///   - milestone: 里程碑编号
    /// - Returns: 创建的 GitHubIssue 对象
    func createIssue(
        owner: String,
        repo: String,
        title: String,
        body: String? = nil,
        labels: [String]? = nil,
        assignees: [String]? = nil,
        milestone: Int? = nil
    ) async throws -> GitHubIssue {
        let endpoint = "/repos/\(owner)/\(repo)/issues"
        let request = CreateIssueRequest(
            title: title,
            body: body,
            labels: labels,
            assignees: assignees,
            milestone: milestone
        )
        return try await post(endpoint, body: request)
    }

    /// 更新 Issue
    /// - Parameters:
    ///   - owner: 仓库所有者
    ///   - repo: 仓库名称
    ///   - issueNumber: Issue 编号
    ///   - title: Issue 标题
    ///   - body: Issue 描述
    ///   - state: Issue 状态
    ///   - labels: 标签数组
    ///   - assignees: 指派的用户数组
    ///   - milestone: 里程碑编号
    /// - Returns: 更新后的 GitHubIssue 对象
    func updateIssue(
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
        let endpoint = "/repos/\(owner)/\(repo)/issues/\(issueNumber)"
        let request = UpdateIssueRequest(
            title: title,
            body: body,
            state: state,
            labels: labels,
            assignees: assignees,
            milestone: milestone
        )
        return try await patch(endpoint, body: request)
    }

    /// 关闭 Issue
    /// - Parameters:
    ///   - owner: 仓库所有者
    ///   - repo: 仓库名称
    ///   - issueNumber: Issue 编号
    /// - Returns: 更新后的 GitHubIssue 对象
    func closeIssue(
        owner: String,
        repo: String,
        issueNumber: Int
    ) async throws -> GitHubIssue {
        try await updateIssue(owner: owner, repo: repo, issueNumber: issueNumber, state: "closed")
    }

    /// 重新打开 Issue
    /// - Parameters:
    ///   - owner: 仓库所有者
    ///   - repo: 仓库名称
    ///   - issueNumber: Issue 编号
    /// - Returns: 更新后的 GitHubIssue 对象
    func reopenIssue(
        owner: String,
        repo: String,
        issueNumber: Int
    ) async throws -> GitHubIssue {
        try await updateIssue(owner: owner, repo: repo, issueNumber: issueNumber, state: "open")
    }

    /// 获取 Issue 评论列表
    /// - Parameters:
    ///   - owner: 仓库所有者
    ///   - repo: 仓库名称
    ///   - issueNumber: Issue 编号
    ///   - page: 页码
    ///   - perPage: 每页数量
    /// - Returns: GitHubIssueComment 数组
    func getIssueComments(
        owner: String,
        repo: String,
        issueNumber: Int,
        page: Int = 1,
        perPage: Int = 10
    ) async throws -> [GitHubIssueComment] {
        let endpoint = "/repos/\(owner)/\(repo)/issues/\(issueNumber)/comments"
        let params = [
            "page": "\(page)",
            "per_page": "\(perPage)"
        ]
        return try await fetch(endpoint, params: params)
    }

    /// 添加 Issue 评论
    /// - Parameters:
    ///   - owner: 仓库所有者
    ///   - repo: 仓库名称
    ///   - issueNumber: Issue 编号
    ///   - body: 评论内容（支持 Markdown）
    /// - Returns: 创建的 GitHubIssueComment 对象
    func addIssueComment(
        owner: String,
        repo: String,
        issueNumber: Int,
        body: String
    ) async throws -> GitHubIssueComment {
        let endpoint = "/repos/\(owner)/\(repo)/issues/\(issueNumber)/comments"
        let request = CreateIssueCommentRequest(body: body)
        return try await post(endpoint, body: request)
    }

    // MARK: - 私有方法

    /// 发送 GET 请求
    /// - Parameters:
    ///   - endpoint: API 端点
    ///   - params: 查询参数
    /// - Returns: 解码后的数据
    private func fetch<T: Decodable>(
        _ endpoint: String,
        params: [String: String] = [:]
    ) async throws -> T {
        var components = URLComponents(string: baseURL + endpoint)!
        if !params.isEmpty {
            components.queryItems = params.map {
                URLQueryItem(name: $0.key, value: $0.value)
            }
        }

        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"

        // 添加认证头
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if Self.verbose {
            GitHubToolsPlugin.logger.info("\(self.t)GET \(request.url!)")
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubAPIError.invalidResponse
        }

        if Self.verbose {
            GitHubToolsPlugin.logger.info("\(self.t)HTTP \(httpResponse.statusCode)")
        }

        // 处理错误状态码
        guard httpResponse.statusCode == 200 else {
            switch httpResponse.statusCode {
            case 401, 403:
                throw GitHubAPIError.unauthorized
            case 404:
                throw GitHubAPIError.httpError(404)
            case 429:
                throw GitHubAPIError.rateLimited
            default:
                throw GitHubAPIError.httpError(httpResponse.statusCode)
            }
        }

        // 解码响应
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw GitHubAPIError.decodeError(error)
        }
    }

    /// 发送 POST 请求
    /// - Parameters:
    ///   - endpoint: API 端点
    ///   - body: 请求体
    /// - Returns: 解码后的数据
    private func post<T: Decodable, B: Codable>(
        _ endpoint: String,
        body: B
    ) async throws -> T {
        var components = URLComponents(string: baseURL + endpoint)!

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // 添加认证头
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // 编码请求体
        let encodedBody = try JSONEncoder().encode(body)
        request.httpBody = encodedBody

        if Self.verbose {
            GitHubToolsPlugin.logger.info("\(self.t)POST \(request.url!)")
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubAPIError.invalidResponse
        }

        if Self.verbose {
            GitHubToolsPlugin.logger.info("\(self.t)HTTP \(httpResponse.statusCode)")
        }

        // 处理错误状态码
        guard httpResponse.statusCode == 201 else {
            switch httpResponse.statusCode {
            case 401, 403:
                throw GitHubAPIError.unauthorized
            case 404:
                throw GitHubAPIError.httpError(404)
            case 429:
                throw GitHubAPIError.rateLimited
            default:
                throw GitHubAPIError.httpError(httpResponse.statusCode)
            }
        }

        // 解码响应
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw GitHubAPIError.decodeError(error)
        }
    }

    /// 发送 PATCH 请求
    /// - Parameters:
    ///   - endpoint: API 端点
    ///   - body: 请求体
    /// - Returns: 解码后的数据
    private func patch<T: Decodable, B: Codable>(
        _ endpoint: String,
        body: B
    ) async throws -> T {
        var components = URLComponents(string: baseURL + endpoint)!

        var request = URLRequest(url: components.url!)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // 添加认证头
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // 编码请求体
        let encodedBody = try JSONEncoder().encode(body)
        request.httpBody = encodedBody

        if Self.verbose {
            GitHubToolsPlugin.logger.info("\(self.t)PATCH \(request.url!)")
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubAPIError.invalidResponse
        }

        if Self.verbose {
            GitHubToolsPlugin.logger.info("\(self.t)HTTP \(httpResponse.statusCode)")
        }

        // 处理错误状态码
        guard httpResponse.statusCode == 200 else {
            switch httpResponse.statusCode {
            case 401, 403:
                throw GitHubAPIError.unauthorized
            case 404:
                throw GitHubAPIError.httpError(404)
            case 429:
                throw GitHubAPIError.rateLimited
            default:
                throw GitHubAPIError.httpError(httpResponse.statusCode)
            }
        }

        // 解码响应
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw GitHubAPIError.decodeError(error)
        }
    }
}
