import Foundation

/// High-level category inferred for a project based on its files and dependencies.
enum GitHubInsightProjectType: String, Codable, Sendable {
    /// Mobile or Apple-platform application project.
    case mobile
    /// Web application or frontend project.
    case web
    /// Command-line application project.
    case cli
    /// Library, package, or SDK-style project.
    case sdk
    /// General application project.
    case app
    /// Project type could not be inferred confidently.
    case unknown
}

/// Inferred profile for a local project used to build GitHub ecosystem queries.
struct GitHubInsightProjectProfile: Codable, Sendable {
    /// Standardized absolute path to the project root.
    let projectPath: String
    /// Most likely primary programming language.
    let primaryLanguage: String?
    /// Detected frameworks, such as SwiftUI, React, or Vue.
    let frameworks: [String]
    /// Detected package or module dependencies.
    let dependencies: [String]
    /// Inferred project category.
    let projectType: GitHubInsightProjectType
    /// Keywords extracted from README content.
    let keywords: [String]
    /// Short project description extracted from README content.
    let description: String
    /// Optional platform hint, such as Apple platforms.
    let platform: String?

    /// Compact title for display in the knowledge base popover.
    var shortTitle: String {
        let language = primaryLanguage ?? "Unknown"
        let framework = frameworks.first
        if let framework {
            return "\(language) / \(framework)"
        }
        return language
    }
}

/// Relationship between a discovered repository and the current project.
enum GitHubInsightRelationType: String, Codable, CaseIterable, Sendable {
    /// Repository may replace or compete with a current dependency.
    case alternative
    /// Repository may work alongside the current stack.
    case complementary
    /// Repository may demonstrate conventions or usage patterns.
    case example

    /// Localized display title for the relation type.
    var title: String {
        switch self {
        case .alternative: return String(localized: "Alternative", table: "GitHubInsight")
        case .complementary: return String(localized: "Complementary", table: "GitHubInsight")
        case .example: return String(localized: "Example", table: "GitHubInsight")
        }
    }
}

/// Cached GitHub repository reference discovered for a project ecosystem.
struct GitHubInsightKBEntry: Identifiable, Codable, Sendable {
    /// Stable identity for SwiftUI lists and persistence.
    let id: UUID
    /// Public GitHub repository URL.
    let repoURL: String
    /// Repository full name in `owner/repo` format.
    let fullName: String
    /// Repository description returned by GitHub.
    let description: String
    /// GitHub star count at sync time.
    let stars: Int
    /// Primary language reported by GitHub.
    let language: String?
    /// GitHub topics assigned to the repository.
    let topics: [String]
    /// Last push date parsed from the GitHub API response.
    let lastPushedAt: Date?
    /// Heuristic relevance score for the current project profile.
    let relevanceScore: Double
    /// Discovered relationship to the current project.
    let relationType: GitHubInsightRelationType
    /// Human-readable signals explaining why this entry may be useful.
    let keyInsights: [String]
    /// Date when this entry was synced.
    let syncedAt: Date
}

/// Current synchronization state for a project's GitHub ecosystem knowledge base.
enum GitHubInsightSyncState: Equatable, Sendable {
    /// No sync is running and no visible cache is available.
    case idle
    /// A sync task is currently running.
    case syncing
    /// Cache is available with the given entry count.
    case ready(count: Int)
    /// GitHub API rejected requests because of rate limiting.
    case rateLimited
    /// Sync failed with a user-displayable error message.
    case failed(String)
}

/// Persisted knowledge base payload for a single project.
struct GitHubInsightProjectStore: Codable, Sendable {
    /// Standardized absolute path to the project root.
    let projectPath: String
    /// Project profile used to produce the cached entries.
    let profile: GitHubInsightProjectProfile
    /// Cached GitHub ecosystem entries.
    let entries: [GitHubInsightKBEntry]
    /// Date when this store was last written.
    let syncedAt: Date
}
