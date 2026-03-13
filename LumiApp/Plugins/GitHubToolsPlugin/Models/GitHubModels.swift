import Foundation

// MARK: - GitHub 用户

/// GitHub 用户信息
struct GitHubUser: Codable, Sendable {
    /// 用户登录名
    let login: String
    /// 用户 ID
    let id: Int
    /// 头像 URL
    let avatarUrl: String
    /// 个人主页 URL
    let htmlUrl: String
    /// 用户类型
    let type: String?

    enum CodingKeys: String, CodingKey {
        case login, id
        case avatarUrl = "avatar_url"
        case htmlUrl = "html_url"
        case type
    }
}

// MARK: - GitHub 仓库

/// GitHub 仓库信息
struct GitHubRepository: Codable, Sendable {
    /// 仓库 ID
    let id: Int
    /// 仓库名称
    let name: String
    /// 完整名称（owner/repo）
    let fullName: String
    /// 仓库描述
    let description: String?
    /// 仓库主页 URL
    let htmlUrl: String
    /// 主要编程语言
    let language: String?
    /// Star 数量
    let stargazersCount: Int
    /// Fork 数量
    let forksCount: Int
    /// 开放 Issue 数量
    let openIssuesCount: Int?
    /// 仓库所有者
    let owner: GitHubUser
    /// 创建时间
    let createdAt: String
    /// 更新时间
    let updatedAt: String
    /// 默认分支
    let defaultBranch: String?
    /// 是否是私有仓库
    let isPrivate: Bool

    enum CodingKeys: String, CodingKey {
        case id, name
        case fullName = "full_name"
        case description
        case htmlUrl = "html_url"
        case language
        case stargazersCount = "stargazers_count"
        case forksCount = "forks_count"
        case openIssuesCount = "open_issues_count"
        case owner
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case defaultBranch = "default_branch"
        case isPrivate = "private"
    }
}

// MARK: - GitHub 搜索结果

/// GitHub 搜索结果
struct GitHubSearchResult: Codable, Sendable {
    /// 总结果数
    let totalCount: Int
    /// 结果是否完整
    let incompleteResults: Bool
    /// 仓库列表
    let items: [GitHubRepository]

    enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case incompleteResults = "incomplete_results"
        case items
    }
}

// MARK: - GitHub 文件内容

/// GitHub 文件内容
struct GitHubFileContent: Codable, Sendable {
    /// 文件名
    let name: String
    /// 文件路径
    let path: String
    /// 文件 SHA 值
    let sha: String
    /// 文件大小（字节）
    let size: Int
    /// API URL
    let url: String
    /// 网页 URL
    let htmlUrl: String
    /// Git URL
    let gitUrl: String
    /// 下载 URL
    let downloadUrl: String?
    /// 文件类型（file/dir/symlink）
    let type: String
    /// 文件内容（Base64 编码）
    let content: String?
    /// 编码方式
    let encoding: String?

    enum CodingKeys: String, CodingKey {
        case name, path, sha, size, url
        case htmlUrl = "html_url"
        case gitUrl = "git_url"
        case downloadUrl = "download_url"
        case type, content, encoding
    }

    /// 解码后的内容（处理 Base64 编码）
    var decodedContent: String? {
        guard let content = content,
              let data = Data(base64Encoded: content, options: .ignoreUnknownCharacters),
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }
}

// MARK: - GitHub 趋势项目

/// GitHub 趋势项目
struct GitHubTrendingRepo: Sendable {
    /// 仓库信息
    let repository: GitHubRepository
    /// 趋势描述（如 "今日新增 stars"）
    let trendDescription: String?
    /// 趋势语言
    let trendLanguage: String?
}

// MARK: - 错误类型

/// GitHub API 错误
enum GitHubAPIError: LocalizedError {
    /// 无效的 API 响应
    case invalidResponse
    /// HTTP 错误
    case httpError(Int)
    /// 数据解析失败
    case decodeError(Error)
    /// API 请求超限
    case rateLimited
    /// 未授权
    case unauthorized
    /// 网络错误
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "无效的 API 响应"
        case .httpError(let code):
            return "HTTP 错误：\(code)"
        case .decodeError(let error):
            return "数据解析失败：\(error.localizedDescription)"
        case .rateLimited:
            return "API 请求超限，请稍后重试"
        case .unauthorized:
            return "认证失败，请检查 GitHub Token"
        case .networkError(let error):
            return "网络错误：\(error.localizedDescription)"
        }
    }
}
