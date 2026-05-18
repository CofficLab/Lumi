import Foundation

enum GitHubInsightProjectType: String, Codable, Sendable {
    case mobile
    case web
    case cli
    case sdk
    case app
    case unknown
}

struct GitHubInsightProjectProfile: Codable, Sendable {
    let projectPath: String
    let primaryLanguage: String?
    let frameworks: [String]
    let dependencies: [String]
    let projectType: GitHubInsightProjectType
    let keywords: [String]
    let description: String
    let platform: String?

    var shortTitle: String {
        let language = primaryLanguage ?? "Unknown"
        let framework = frameworks.first
        if let framework {
            return "\(language) / \(framework)"
        }
        return language
    }
}

enum GitHubInsightRelationType: String, Codable, CaseIterable, Sendable {
    case alternative
    case complementary
    case example

    var title: String {
        switch self {
        case .alternative: return String(localized: "Alternative", table: "GitHubInsight")
        case .complementary: return String(localized: "Complementary", table: "GitHubInsight")
        case .example: return String(localized: "Example", table: "GitHubInsight")
        }
    }
}

struct GitHubInsightKBEntry: Identifiable, Codable, Sendable {
    let id: UUID
    let repoURL: String
    let fullName: String
    let description: String
    let stars: Int
    let language: String?
    let topics: [String]
    let lastPushedAt: Date?
    let relevanceScore: Double
    let relationType: GitHubInsightRelationType
    let keyInsights: [String]
    let syncedAt: Date
}

enum GitHubInsightSyncState: Equatable, Sendable {
    case idle
    case syncing
    case ready(count: Int)
    case rateLimited
    case failed(String)
}

struct GitHubInsightProjectStore: Codable, Sendable {
    let projectPath: String
    let profile: GitHubInsightProjectProfile
    let entries: [GitHubInsightKBEntry]
    let syncedAt: Date
}
