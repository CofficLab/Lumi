import Testing
import Foundation
@testable import ProjectIssueScannerPlugin

/// Unit tests for the extracted `IssueRelevanceRanker` relevance-scoring logic.
@Suite struct IssueRelevanceRankerTests {

    private func issue(
        severity: ProjectIssueSeverity = .info,
        filePath: String = "/src/app.swift",
        title: String = "TODO",
        description: String = "",
        suggestion: String? = nil,
        source: ProjectIssueSource = .localRule,
        updatedAt: Date = Date(timeIntervalSince1970: 1000)
    ) -> ProjectIssue {
        ProjectIssue(
            type: .todo,
            severity: severity,
            projectPath: "/src",
            filePath: filePath,
            lineNumber: nil,
            title: title,
            description: description,
            suggestion: suggestion,
            source: source
        )
    }

    // MARK: - severityScore

    @Test func severityScoreOrdering() {
        #expect(IssueRelevanceRanker.severityScore(.critical) > IssueRelevanceRanker.severityScore(.warning))
        #expect(IssueRelevanceRanker.severityScore(.warning) > IssueRelevanceRanker.severityScore(.info))
    }

    @Test func severityScoreValuesAreStable() {
        #expect(IssueRelevanceRanker.severityScore(.critical) == 6)
        #expect(IssueRelevanceRanker.severityScore(.warning) == 4)
        #expect(IssueRelevanceRanker.severityScore(.info) == 2)
    }

    // MARK: - tokenize

    @Test func tokenizeSplitsOnNonAlphanumeric() {
        let tokens = IssueRelevanceRanker.tokenize("auth login, swift!")
        #expect(tokens.contains("auth"))
        #expect(tokens.contains("login"))
        #expect(tokens.contains("swift"))
    }

    @Test func tokenizeFiltersShortTokens() {
        let tokens = IssueRelevanceRanker.tokenize("a ab abc")
        // Tokens with fewer than 3 chars are dropped.
        #expect(!tokens.contains("a"))
        #expect(!tokens.contains("ab"))
        #expect(tokens.contains("abc"))
    }

    @Test func tokenizeIsLowercased() {
        #expect(IssueRelevanceRanker.tokenize("AUTH").contains("auth"))
    }

    // MARK: - pickRelevantIssues

    @Test func returnsEmptyForNoIssues() {
        let result = IssueRelevanceRanker.pickRelevantIssues(issues: [], message: "anything")
        #expect(result.isEmpty)
    }

    @Test func ranksHigherSeverityFirst() {
        let info = issue(severity: .info, title: "auth login")
        let critical = issue(severity: .critical, title: "auth login")
        let result = IssueRelevanceRanker.pickRelevantIssues(
            issues: [info, critical], message: "auth login"
        )
        #expect(result.first?.severity == .critical)
    }

    @Test func messageTextMatchBoostsRanking() {
        // Two issues of equal severity; one shares tokens with the message.
        let unrelated = issue(severity: .warning, title: "kitchen recipe", description: "cook food")
        let related = issue(severity: .warning, title: "auth login", description: "handle authentication")
        let result = IssueRelevanceRanker.pickRelevantIssues(
            issues: [unrelated, related], message: "fix the auth login flow"
        )
        #expect(result.first?.title == "auth login")
    }

    @Test func filePathMatchIsWeightedHigherThanText() {
        // Path match contributes *3 per token vs *1 for text match.
        let textMatch = issue(severity: .info, filePath: "/other/util.swift", title: "authentication", description: "login")
        let pathMatch = issue(severity: .info, filePath: "/src/auth/login.swift", title: "unrelated", description: "nothing")
        let result = IssueRelevanceRanker.pickRelevantIssues(
            issues: [textMatch, pathMatch], message: "auth login"
        )
        // Both share tokens; path match should win due to 3x weighting.
        #expect(result.first?.filePath == "/src/auth/login.swift")
    }

    @Test func llmAnalysisGetsSmallBonus() {
        let local = issue(severity: .info, title: "auth login", source: .localRule)
        let llm = issue(severity: .info, title: "auth login", source: .llmAnalysis)
        let result = IssueRelevanceRanker.pickRelevantIssues(
            issues: [local, llm], message: "auth login"
        )
        #expect(result.first?.source == .llmAnalysis)
    }

    @Test func limitsToMaxResults() {
        let issues = (0..<10).map { i in
            issue(severity: .info, title: "issue number \(i)", updatedAt: Date(timeIntervalSince1970: Double(i)))
        }
        let result = IssueRelevanceRanker.pickRelevantIssues(
            issues: issues, message: "issue number", maxResults: 3
        )
        #expect(result.count == 3)
    }

    @Test func tiesBrokenByRecency() {
        let older = issue(severity: .info, title: "auth login", updatedAt: Date(timeIntervalSince1970: 100))
        let newer = issue(severity: .info, title: "auth login", updatedAt: Date(timeIntervalSince1970: 200))
        let result = IssueRelevanceRanker.pickRelevantIssues(
            issues: [older, newer], message: "auth login"
        )
        #expect(result.first?.updatedAt == newer.updatedAt)
    }
}
