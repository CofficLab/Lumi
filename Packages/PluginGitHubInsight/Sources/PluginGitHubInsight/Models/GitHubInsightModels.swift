import Foundation
import ProjectProfileKit

/// GitHubInsight 使用的项目分类兼容别名。
public typealias GitHubInsightProjectType = ProjectType

/// GitHubInsight 使用的项目画像兼容别名。
public typealias GitHubInsightProjectProfile = ProjectProfile

/// GitHubInsight 使用的项目画像器兼容别名。
public typealias GitHubInsightProjectProfiler = ProjectProfiler

/// 为项目生态发现并缓存的 GitHub 仓库参考。
public struct GitHubInsightKBEntry: Identifiable, Codable, Sendable {
    /// 用于 SwiftUI 列表和持久化的稳定标识。
    public let id: UUID
    /// 公开的 GitHub 仓库 URL。
    public let repoURL: String
    /// `owner/repo` 格式的仓库完整名称。
    public let fullName: String
    /// GitHub 返回的仓库描述。
    public let description: String
    /// 同步时的 GitHub star 数。
    public let stars: Int
    /// GitHub 报告的主要语言。
    public let language: String?
    /// 仓库设置的 GitHub topics。
    public let topics: [String]
    /// 从 GitHub API 响应中解析出的最后 push 时间。
    public let lastPushedAt: Date?
    /// 针对当前项目画像的启发式相关性分数。
    public let relevanceScore: Double
    /// 解释该条目为什么可能有用的可读信号。
    public let keyInsights: [String]
    /// 该条目的同步时间。
    public let syncedAt: Date
}

/// 项目 GitHub 生态知识库的当前同步状态。
public enum GitHubInsightSyncState: Equatable, Sendable {
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
public struct GitHubInsightProjectStore: Codable, Sendable {
    /// 标准化后的项目根目录绝对路径。
    public let projectPath: String
    /// 生成缓存条目时使用的项目画像。
    public let profile: GitHubInsightProjectProfile
    /// 缓存的 GitHub 生态条目。
    public let entries: [GitHubInsightKBEntry]
    /// 该存储最后写入的时间。
    public let syncedAt: Date
}
