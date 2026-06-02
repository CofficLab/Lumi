import Foundation

public struct ReviewReport: Identifiable, Codable, Sendable {
    public let id: UUID
    public let repositoryPath: String
    public let scope: ReviewScope
    public let baseCommitHash: String?
    public let diffStats: ReviewDiffStats
    public let overallScore: Double
    public let summary: String
    public let issues: [ReviewIssue]
    public let suggestions: [ReviewSuggestion]
    public let createdAt: Date
}

public struct ReviewIssue: Identifiable, Codable, Sendable {
    public let id: UUID
    public let severity: ReviewSeverity
    public let category: ReviewCategory
    public let file: String
    public let line: Int?
    public let range: ReviewLineRange?
    public let description: String
    public let rationale: String
    public let fixSuggestion: String?
    public let suggestedPatch: String?
    public let confidence: Double
}

public struct ReviewSuggestion: Identifiable, Codable, Sendable {
    public let id: UUID
    public let title: String
    public let description: String
    public let suggestedPatch: String?
}

public struct ReviewLineRange: Codable, Sendable {
    public let start: Int
    public let end: Int
}

public enum ReviewSeverity: String, Codable, Sendable, CaseIterable {
    case critical
    case warning
    case info
}

public enum ReviewCategory: String, Codable, Sendable, CaseIterable {
    case bug
    case security
    case performance
    case style
    case test
    case maintainability
}

public enum ReviewScope: String, Codable, Sendable, CaseIterable {
    case staged
    case unstaged
    case allUncommitted
}

public struct ReviewDiffStats: Codable, Sendable {
    public let filesChanged: Int
    public let insertions: Int
    public let deletions: Int

    public static let empty = ReviewDiffStats(filesChanged: 0, insertions: 0, deletions: 0)

    public static func + (lhs: ReviewDiffStats, rhs: ReviewDiffStats) -> ReviewDiffStats {
        ReviewDiffStats(
            filesChanged: lhs.filesChanged + rhs.filesChanged,
            insertions: lhs.insertions + rhs.insertions,
            deletions: lhs.deletions + rhs.deletions
        )
    }
}

public enum ReviewState: Codable, Sendable, Equatable {
    case idle
    case reviewing
    case completed(reportId: UUID)
    case failed(message: String)
}
