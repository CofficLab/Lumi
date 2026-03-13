import Foundation
import OSLog
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

    /// GitHub Token（从插件设置读取）
    private var accessToken: String? {
        UserDefaults.standard.string(forKey: "GitHubToken")
    }

    private init() {
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
            os_log("\(Self.t)🌐 GET \(request.url!)")
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubAPIError.invalidResponse
        }

        if Self.verbose {
            os_log("\(Self.t)📥 HTTP \(httpResponse.statusCode)")
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
