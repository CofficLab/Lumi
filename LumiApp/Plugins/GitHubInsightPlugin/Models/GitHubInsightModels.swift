import Foundation

/// 根据项目文件和依赖推断出的项目高层分类。
enum GitHubInsightProjectType: String, Codable, Sendable {
    /// 移动端或 Apple 平台应用项目。
    case mobile
    /// Web 应用或前端项目。
    case web
    /// 命令行应用项目。
    case cli
    /// 库、包或 SDK 类型项目。
    case sdk
    /// 通用应用项目。
    case app
    /// 无法可靠推断项目类型。
    case unknown
}

/// 为构建 GitHub 生态查询而推断出的本地项目画像。
struct GitHubInsightProjectProfile: Codable, Sendable {
    /// 标准化后的项目根目录绝对路径。
    let projectPath: String
    /// 最可能的主要编程语言。
    let primaryLanguage: String?
    /// 检测到的框架，例如 SwiftUI、React 或 Vue。
    let frameworks: [String]
    /// 检测到的包或模块依赖。
    let dependencies: [String]
    /// 推断出的项目分类。
    let projectType: GitHubInsightProjectType
    /// 从 README 内容中提取的关键词。
    let keywords: [String]
    /// 从 README 内容中提取的项目简短描述。
    let description: String
    /// 可选平台提示，例如 Apple platforms。
    let platform: String?

    /// 用于知识库弹窗展示的紧凑标题。
    var shortTitle: String {
        let language = primaryLanguage ?? "Unknown"
        let framework = frameworks.first
        if let framework {
            return "\(language) / \(framework)"
        }
        return language
    }
}

/// 发现仓库与当前项目之间的关系。
enum GitHubInsightRelationType: String, Codable, CaseIterable, Sendable {
    /// 仓库可能替换当前依赖或与其竞争。
    case alternative
    /// 仓库可能与当前技术栈配套使用。
    case complementary
    /// 仓库可能展示约定或使用模式。
    case example

    /// 关系类型的本地化展示标题。
    var title: String {
        switch self {
        case .alternative: return String(localized: "Alternative", table: "GitHubInsight")
        case .complementary: return String(localized: "Complementary", table: "GitHubInsight")
        case .example: return String(localized: "Example", table: "GitHubInsight")
        }
    }
}

/// 为项目生态发现并缓存的 GitHub 仓库参考。
struct GitHubInsightKBEntry: Identifiable, Codable, Sendable {
    /// 用于 SwiftUI 列表和持久化的稳定标识。
    let id: UUID
    /// 公开的 GitHub 仓库 URL。
    let repoURL: String
    /// `owner/repo` 格式的仓库完整名称。
    let fullName: String
    /// GitHub 返回的仓库描述。
    let description: String
    /// 同步时的 GitHub star 数。
    let stars: Int
    /// GitHub 报告的主要语言。
    let language: String?
    /// 仓库设置的 GitHub topics。
    let topics: [String]
    /// 从 GitHub API 响应中解析出的最后 push 时间。
    let lastPushedAt: Date?
    /// 针对当前项目画像的启发式相关性分数。
    let relevanceScore: Double
    /// 与当前项目的发现关系。
    let relationType: GitHubInsightRelationType
    /// 解释该条目为什么可能有用的可读信号。
    let keyInsights: [String]
    /// 该条目的同步时间。
    let syncedAt: Date
}

/// 项目 GitHub 生态知识库的当前同步状态。
enum GitHubInsightSyncState: Equatable, Sendable {
    /// 没有同步任务运行，且没有可见缓存。
    case idle
    /// 同步任务正在运行。
    case syncing
    /// 缓存可用，并带有指定条目数。
    case ready(count: Int)
    /// GitHub API 因限流拒绝请求。
    case rateLimited
    /// 同步失败，并带有可展示给用户的错误消息。
    case failed(String)
}

/// 单个项目持久化的知识库载荷。
struct GitHubInsightProjectStore: Codable, Sendable {
    /// 标准化后的项目根目录绝对路径。
    let projectPath: String
    /// 生成缓存条目时使用的项目画像。
    let profile: GitHubInsightProjectProfile
    /// 缓存的 GitHub 生态条目。
    let entries: [GitHubInsightKBEntry]
    /// 该存储最后写入的时间。
    let syncedAt: Date
}
