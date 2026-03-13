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

// MARK: - GitHub Issue

/// GitHub Issue 状态
enum GitHubIssueState: String, Codable, Sendable {
    case open
    case closed
    case all
}

/// GitHub Issue 信息
struct GitHubIssue: Codable, Sendable {
    /// Issue ID
    let id: Int
    /// Issue 编号（仓库内唯一）
    let number: Int
    /// Issue 标题
    let title: String
    /// Issue 描述
    let body: String?
    /// Issue 状态
    let state: GitHubIssueState
    /// Issue 创建者
    let user: GitHubUser
    /// Issue 网页 URL
    let htmlUrl: String
    /// 关联的 Issue URL（如果有）
    let repositoryUrl: String?
    /// Issue 创建时间
    let createdAt: String
    /// Issue 更新时间
    let updatedAt: String
    /// Issue 关闭时间
    let closedAt: String?
    /// 评论数量
    let comments: Int
    /// 标签列表
    let labels: [GitHubLabel]
    /// 关联的里程碑（可选）
    let milestone: GitHubMilestone?
    /// 被引用的 Issue/PR 列表
    let pulledThrough: [String]?

    enum CodingKeys: String, CodingKey {
        case id, number, title, body, state, user
        case htmlUrl = "html_url"
        case repositoryUrl = "repository_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case closedAt = "closed_at"
        case comments, labels, milestone
        case pulledThrough = "pull_request"
    }
}

/// GitHub 标签
struct GitHubLabel: Codable, Sendable {
    /// 标签 ID
    let id: Int
    /// 标签名称
    let name: String
    /// 标签颜色（6 位十六进制）
    let color: String
    /// 标签描述
    let description: String?

    enum CodingKeys: String, CodingKey {
        case id, name, color, description
    }
}

/// GitHub 里程碑
struct GitHubMilestone: Codable, Sendable {
    /// 里程碑 ID
    let id: Int
    /// 里程碑编号
    let number: Int
    /// 里程碑标题
    let title: String
    /// 里程碑描述
    let description: String?
    /// 里程碑状态
    let state: GitHubIssueState
    /// 里程碑创建时间
    let createdAt: String
    /// 里程碑截止时间
    let dueOn: String?
    /// 里程碑关闭时间
    let closedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, number, title, description, state
        case createdAt = "created_at"
        case dueOn = "due_on"
        case closedAt = "closed_at"
    }
}

/// GitHub Issue 评论
struct GitHubIssueComment: Codable, Sendable {
    /// 评论 ID
    let id: Int
    /// 评论者
    let user: GitHubUser
    /// 评论内容（支持 Markdown）
    let body: String
    /// 评论创建时间
    let createdAt: String
    /// 评论更新时间
    let updatedAt: String
    /// 评论 HTML URL
    let htmlUrl: String

    enum CodingKeys: String, CodingKey {
        case id, user, body
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case htmlUrl = "html_url"
    }
}

/// 创建 Issue 请求
struct CreateIssueRequest: Codable {
    /// Issue 标题（必需）
    let title: String
    /// Issue 描述（可选）
    let body: String?
    /// 标签名称数组（可选）
    let labels: [String]?
    /// 指派的用户（可选）
    let assignees: [String]?
    /// 里程碑编号（可选）
    let milestone: Int?

    enum CodingKeys: String, CodingKey {
        case title, body, labels, assignees, milestone
    }
}

/// 更新 Issue 请求
struct UpdateIssueRequest: Codable {
    /// Issue 标题（可选）
    let title: String?
    /// Issue 描述（可选）
    let body: String?
    /// Issue 状态（可选）
    let state: String?
    /// 标签名称数组（可选）
    let labels: [String]?
    /// 指派的用户数组（可选）
    let assignees: [String]?
    /// 里程碑编号（可选，nil 表示移除）
    let milestone: Int?

    enum CodingKeys: String, CodingKey {
        case title, body, state, labels, assignees, milestone
    }
}

/// 创建评论请求
struct CreateIssueCommentRequest: Codable {
    /// 评论内容（支持 Markdown）
    let body: String

    enum CodingKeys: String, CodingKey {
        case body
    }
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
