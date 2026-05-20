import Foundation

// MARK: - GitHub 用户

/// GitHub 用户信息。
public struct GitHubUser: Codable, Sendable {
    /// 用户登录名。
    public let login: String
    /// 用户 ID。
    public let id: Int
    /// 头像 URL。
    public let avatarUrl: String
    /// 个人主页 URL。
    public let htmlUrl: String
    /// 用户类型。
    public let type: String?

    /// 创建 GitHub 用户信息。
    public init(login: String, id: Int, avatarUrl: String, htmlUrl: String, type: String?) {
        self.login = login
        self.id = id
        self.avatarUrl = avatarUrl
        self.htmlUrl = htmlUrl
        self.type = type
    }

    enum CodingKeys: String, CodingKey {
        case login, id
        case avatarUrl = "avatar_url"
        case htmlUrl = "html_url"
        case type
    }
}

// MARK: - GitHub 仓库

/// GitHub 仓库信息。
public struct GitHubRepository: Codable, Sendable {
    /// 仓库 ID。
    public let id: Int
    /// 仓库名称。
    public let name: String
    /// `owner/repo` 格式的仓库完整名称。
    public let fullName: String
    /// 仓库描述。
    public let description: String?
    /// 仓库主页 URL。
    public let htmlUrl: String
    /// 主要编程语言。
    public let language: String?
    /// Star 数量。
    public let stargazersCount: Int
    /// Fork 数量。
    public let forksCount: Int
    /// 开放 Issue 数量。
    public let openIssuesCount: Int?
    /// 仓库 topics。
    public let topics: [String]?
    /// 最后 push 时间。
    public let pushedAt: String?
    /// 是否归档。
    public let archived: Bool?
    /// 是否 fork。
    public let fork: Bool?
    /// 仓库所有者。
    public let owner: GitHubUser
    /// 创建时间。
    public let createdAt: String
    /// 更新时间。
    public let updatedAt: String
    /// 默认分支。
    public let defaultBranch: String?
    /// 是否是私有仓库。
    public let isPrivate: Bool

    /// 创建 GitHub 仓库信息。
    public init(
        id: Int,
        name: String,
        fullName: String,
        description: String?,
        htmlUrl: String,
        language: String?,
        stargazersCount: Int,
        forksCount: Int,
        openIssuesCount: Int?,
        topics: [String]?,
        pushedAt: String?,
        archived: Bool?,
        fork: Bool?,
        owner: GitHubUser,
        createdAt: String,
        updatedAt: String,
        defaultBranch: String?,
        isPrivate: Bool
    ) {
        self.id = id
        self.name = name
        self.fullName = fullName
        self.description = description
        self.htmlUrl = htmlUrl
        self.language = language
        self.stargazersCount = stargazersCount
        self.forksCount = forksCount
        self.openIssuesCount = openIssuesCount
        self.topics = topics
        self.pushedAt = pushedAt
        self.archived = archived
        self.fork = fork
        self.owner = owner
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.defaultBranch = defaultBranch
        self.isPrivate = isPrivate
    }

    enum CodingKeys: String, CodingKey {
        case id, name
        case fullName = "full_name"
        case description
        case htmlUrl = "html_url"
        case language
        case stargazersCount = "stargazers_count"
        case forksCount = "forks_count"
        case openIssuesCount = "open_issues_count"
        case topics
        case pushedAt = "pushed_at"
        case archived
        case fork
        case owner
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case defaultBranch = "default_branch"
        case isPrivate = "private"
    }
}

// MARK: - GitHub 搜索结果

/// GitHub 仓库搜索结果。
public struct GitHubSearchResult: Codable, Sendable {
    /// 总结果数。
    public let totalCount: Int
    /// 结果是否完整。
    public let incompleteResults: Bool
    /// 仓库列表。
    public let items: [GitHubRepository]

    /// 创建 GitHub 仓库搜索结果。
    public init(totalCount: Int, incompleteResults: Bool, items: [GitHubRepository]) {
        self.totalCount = totalCount
        self.incompleteResults = incompleteResults
        self.items = items
    }

    enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case incompleteResults = "incomplete_results"
        case items
    }
}

// MARK: - GitHub 文件内容

/// GitHub 文件内容。
public struct GitHubFileContent: Codable, Sendable {
    /// 文件名。
    public let name: String
    /// 文件路径。
    public let path: String
    /// 文件 SHA 值。
    public let sha: String
    /// 文件大小，单位为字节。
    public let size: Int
    /// API URL。
    public let url: String
    /// 网页 URL。
    public let htmlUrl: String
    /// Git URL。
    public let gitUrl: String
    /// 下载 URL。
    public let downloadUrl: String?
    /// 文件类型，例如 `file`、`dir` 或 `symlink`。
    public let type: String
    /// Base64 编码的文件内容。
    public let content: String?
    /// 编码方式。
    public let encoding: String?

    /// 创建 GitHub 文件内容。
    public init(
        name: String,
        path: String,
        sha: String,
        size: Int,
        url: String,
        htmlUrl: String,
        gitUrl: String,
        downloadUrl: String?,
        type: String,
        content: String?,
        encoding: String?
    ) {
        self.name = name
        self.path = path
        self.sha = sha
        self.size = size
        self.url = url
        self.htmlUrl = htmlUrl
        self.gitUrl = gitUrl
        self.downloadUrl = downloadUrl
        self.type = type
        self.content = content
        self.encoding = encoding
    }

    enum CodingKeys: String, CodingKey {
        case name, path, sha, size, url
        case htmlUrl = "html_url"
        case gitUrl = "git_url"
        case downloadUrl = "download_url"
        case type, content, encoding
    }

    /// 解码后的 UTF-8 文本内容。
    public var decodedContent: String? {
        guard let content,
              let data = Data(base64Encoded: content, options: .ignoreUnknownCharacters),
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }
}

// MARK: - GitHub 趋势项目

/// GitHub 趋势项。
public struct GitHubTrendingRepo: Sendable {
    /// 仓库信息。
    public let repository: GitHubRepository
    /// 趋势描述。
    public let trendDescription: String?
    /// 趋势语言。
    public let trendLanguage: String?

    /// 创建 GitHub 趋势项。
    public init(repository: GitHubRepository, trendDescription: String?, trendLanguage: String?) {
        self.repository = repository
        self.trendDescription = trendDescription
        self.trendLanguage = trendLanguage
    }
}

// MARK: - GitHub Issue

/// GitHub Issue 状态。
public enum GitHubIssueState: String, Codable, Sendable {
    case open
    case closed
    case all
}

/// GitHub Issue 信息。
public struct GitHubIssue: Codable, Sendable {
    /// Issue ID。
    public let id: Int
    /// Issue 编号。
    public let number: Int
    /// Issue 标题。
    public let title: String
    /// Issue 描述。
    public let body: String?
    /// Issue 状态。
    public let state: GitHubIssueState
    /// Issue 创建者。
    public let user: GitHubUser
    /// Issue 网页 URL。
    public let htmlUrl: String
    /// 关联的仓库 API URL。
    public let repositoryUrl: String?
    /// Issue 创建时间。
    public let createdAt: String
    /// Issue 更新时间。
    public let updatedAt: String
    /// Issue 关闭时间。
    public let closedAt: String?
    /// 评论数量。
    public let comments: Int
    /// 标签列表。
    public let labels: [GitHubLabel]
    /// 关联的里程碑。
    public let milestone: GitHubMilestone?
    /// 关联的 Pull Request 信息。
    public let pulledThrough: [String]?

    /// 创建 GitHub Issue 信息。
    public init(
        id: Int,
        number: Int,
        title: String,
        body: String?,
        state: GitHubIssueState,
        user: GitHubUser,
        htmlUrl: String,
        repositoryUrl: String?,
        createdAt: String,
        updatedAt: String,
        closedAt: String?,
        comments: Int,
        labels: [GitHubLabel],
        milestone: GitHubMilestone?,
        pulledThrough: [String]?
    ) {
        self.id = id
        self.number = number
        self.title = title
        self.body = body
        self.state = state
        self.user = user
        self.htmlUrl = htmlUrl
        self.repositoryUrl = repositoryUrl
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.closedAt = closedAt
        self.comments = comments
        self.labels = labels
        self.milestone = milestone
        self.pulledThrough = pulledThrough
    }

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

/// GitHub 标签。
public struct GitHubLabel: Codable, Sendable {
    /// 标签 ID。
    public let id: Int
    /// 标签名称。
    public let name: String
    /// 标签颜色，格式为 6 位十六进制。
    public let color: String
    /// 标签描述。
    public let description: String?

    /// 创建 GitHub 标签。
    public init(id: Int, name: String, color: String, description: String?) {
        self.id = id
        self.name = name
        self.color = color
        self.description = description
    }
}

/// GitHub 里程碑。
public struct GitHubMilestone: Codable, Sendable {
    /// 里程碑 ID。
    public let id: Int
    /// 里程碑编号。
    public let number: Int
    /// 里程碑标题。
    public let title: String
    /// 里程碑描述。
    public let description: String?
    /// 里程碑状态。
    public let state: GitHubIssueState
    /// 里程碑创建时间。
    public let createdAt: String
    /// 里程碑截止时间。
    public let dueOn: String?
    /// 里程碑关闭时间。
    public let closedAt: String?

    /// 创建 GitHub 里程碑。
    public init(
        id: Int,
        number: Int,
        title: String,
        description: String?,
        state: GitHubIssueState,
        createdAt: String,
        dueOn: String?,
        closedAt: String?
    ) {
        self.id = id
        self.number = number
        self.title = title
        self.description = description
        self.state = state
        self.createdAt = createdAt
        self.dueOn = dueOn
        self.closedAt = closedAt
    }

    enum CodingKeys: String, CodingKey {
        case id, number, title, description, state
        case createdAt = "created_at"
        case dueOn = "due_on"
        case closedAt = "closed_at"
    }
}

/// GitHub Issue 评论。
public struct GitHubIssueComment: Codable, Sendable {
    /// 评论 ID。
    public let id: Int
    /// 评论者。
    public let user: GitHubUser
    /// 评论内容。
    public let body: String
    /// 评论创建时间。
    public let createdAt: String
    /// 评论更新时间。
    public let updatedAt: String
    /// 评论 HTML URL。
    public let htmlUrl: String

    /// 创建 GitHub Issue 评论。
    public init(id: Int, user: GitHubUser, body: String, createdAt: String, updatedAt: String, htmlUrl: String) {
        self.id = id
        self.user = user
        self.body = body
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.htmlUrl = htmlUrl
    }

    enum CodingKeys: String, CodingKey {
        case id, user, body
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case htmlUrl = "html_url"
    }
}

/// 创建 Issue 请求。
struct CreateIssueRequest: Codable {
    let title: String
    let body: String?
    let labels: [String]?
    let assignees: [String]?
    let milestone: Int?
}

/// 更新 Issue 请求。
struct UpdateIssueRequest: Codable {
    let title: String?
    let body: String?
    let state: String?
    let labels: [String]?
    let assignees: [String]?
    let milestone: Int?
}

/// 创建 Issue 评论请求。
struct CreateIssueCommentRequest: Codable {
    let body: String
}

// MARK: - 错误类型

/// GitHub API 错误。
public enum GitHubAPIError: LocalizedError {
    /// 无效的 API 响应。
    case invalidResponse
    /// HTTP 错误。
    case httpError(Int)
    /// 数据解析失败。
    case decodeError(Error)
    /// API 请求超限。
    case rateLimited
    /// 未授权。
    case unauthorized
    /// 网络错误。
    case networkError(Error)

    public var errorDescription: String? {
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
