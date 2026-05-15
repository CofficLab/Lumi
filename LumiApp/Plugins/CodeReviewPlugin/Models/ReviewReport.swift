import Foundation

struct ReviewReport: Identifiable, Codable, Sendable {
    let id: UUID
    let repositoryPath: String
    let scope: ReviewScope
    let baseCommitHash: String?
    let diffStats: ReviewDiffStats
    let overallScore: Double
    let summary: String
    let issues: [ReviewIssue]
    let suggestions: [ReviewSuggestion]
    let createdAt: Date
}

struct ReviewIssue: Identifiable, Codable, Sendable {
    let id: UUID
    let severity: ReviewSeverity
    let category: ReviewCategory
    let file: String
    let line: Int?
    let range: ReviewLineRange?
    let description: String
    let rationale: String
    let fixSuggestion: String?
    let suggestedPatch: String?
    let confidence: Double
}

struct ReviewSuggestion: Identifiable, Codable, Sendable {
    let id: UUID
    let title: String
    let description: String
    let suggestedPatch: String?
}

struct ReviewLineRange: Codable, Sendable {
    let start: Int
    let end: Int
}

enum ReviewSeverity: String, Codable, Sendable, CaseIterable {
    case critical
    case warning
    case info
}

enum ReviewCategory: String, Codable, Sendable, CaseIterable {
    case bug
    case security
    case performance
    case style
    case test
    case maintainability
}

enum ReviewScope: String, Codable, Sendable, CaseIterable {
    case staged
    case unstaged
    case allUncommitted
}

struct ReviewDiffStats: Codable, Sendable {
    let filesChanged: Int
    let insertions: Int
    let deletions: Int

    static let empty = ReviewDiffStats(filesChanged: 0, insertions: 0, deletions: 0)

    static func + (lhs: ReviewDiffStats, rhs: ReviewDiffStats) -> ReviewDiffStats {
        ReviewDiffStats(
            filesChanged: lhs.filesChanged + rhs.filesChanged,
            insertions: lhs.insertions + rhs.insertions,
            deletions: lhs.deletions + rhs.deletions
        )
    }
}

enum ReviewState: Codable, Sendable, Equatable {
    case idle
    case reviewing
    case completed(reportId: UUID)
    case failed(message: String)
}
