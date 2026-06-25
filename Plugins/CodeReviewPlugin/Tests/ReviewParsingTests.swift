import Testing
import Foundation
@testable import CodeReviewPlugin

/// Unit tests for the pure helpers in CodeReviewPlugin: git numstat parsing,
/// diff-stats addition, and report formatting.
@Suite struct ReviewGitDiffStatsTests {

    @Test func additionCombinesFields() {
        let a = ReviewGitDiffStats(filesChanged: 2, insertions: 10, deletions: 5)
        let b = ReviewGitDiffStats(filesChanged: 1, insertions: 3, deletions: 7)
        // ReviewDiffStats (the model) supports +; the git stats type does not,
        // so verify the model addition.
        let ma = ReviewDiffStats(filesChanged: 2, insertions: 10, deletions: 5)
        let mb = ReviewDiffStats(filesChanged: 1, insertions: 3, deletions: 7)
        let sum = ma + mb
        #expect(sum.filesChanged == 3)
        #expect(sum.insertions == 13)
        #expect(sum.deletions == 12)
        _ = (a, b)  // silence unused
    }

    @Test func diffStatsEmptyConstant() {
        #expect(ReviewDiffStats.empty.filesChanged == 0)
        #expect(ReviewDiffStats.empty.insertions == 0)
        #expect(ReviewDiffStats.empty.deletions == 0)
    }
}

@Suite struct ReviewParseNumstatTests {

    @Test func parseNilReturnsNil() {
        #expect(ReviewGitService.parseNumstat(nil) == nil)
    }

    @Test func parseEmptyReturnsNil() {
        #expect(ReviewGitService.parseNumstat("") == nil)
    }

    @Test func parseSingleFile() {
        let stats = ReviewGitService.parseNumstat("12\t3\tsrc/main.swift")
        #expect(stats?.filesChanged == 1)
        #expect(stats?.insertions == 12)
        #expect(stats?.deletions == 3)
    }

    @Test func parseMultipleFilesAggregate() {
        let output = "10\t2\ta.swift\n5\t0\tb.swift\n0\t8\tc.swift"
        let stats = ReviewGitService.parseNumstat(output)
        #expect(stats?.filesChanged == 3)
        #expect(stats?.insertions == 15)
        #expect(stats?.deletions == 10)
    }

    @Test func parseBinaryFileCountsAsZero() {
        // Binary files report "-" for counts → coerced to 0.
        let stats = ReviewGitService.parseNumstat("-\t-\tasset.png")
        #expect(stats?.filesChanged == 1)
        #expect(stats?.insertions == 0)
        #expect(stats?.deletions == 0)
    }

    @Test func parseSkipsMalformedLines() {
        // Lines without 3 tab-separated parts are skipped.
        let stats = ReviewGitService.parseNumstat("not\tvalid\n1\t1\tok.swift")
        #expect(stats?.filesChanged == 1)
    }
}

@Suite struct RunReviewToolFormatTests {

    private func makeIssue(severity: ReviewSeverity, file: String = "f.swift", line: Int? = 1,
                            description: String = "desc", rationale: String = "") -> ReviewIssue {
        ReviewIssue(id: UUID(), severity: severity, category: .bug, file: file,
                    line: line, range: nil, description: description, rationale: rationale,
                    fixSuggestion: nil, suggestedPatch: nil, confidence: 1.0)
    }

    private func makeReport(issues: [ReviewIssue], score: Double = 8.0,
                            diff: ReviewDiffStats = ReviewDiffStats(filesChanged: 3, insertions: 20, deletions: 5)) -> ReviewReport {
        ReviewReport(id: UUID(), repositoryPath: "/repo", scope: .staged, baseCommitHash: nil,
                     diffStats: diff, overallScore: score, summary: "All good.",
                     issues: issues, suggestions: [], createdAt: Date(timeIntervalSince1970: 1_700_000_000))
    }

    @Test func formatIncludesScoreAndDiffAndSummary() {
        let report = makeReport(issues: [], score: 7.5)
        let output = RunReviewTool().format(report: report)
        #expect(output.contains("## Code Review"))
        #expect(output.contains("7.5/10"))
        #expect(output.contains("3 files, +20, -5"))
        #expect(output.contains("All good."))
        #expect(output.contains("0 critical, 0 warnings, 0 info"))
    }

    @Test func formatCountsBySeverity() {
        let issues = [
            makeIssue(severity: .critical),
            makeIssue(severity: .critical),
            makeIssue(severity: .warning),
            makeIssue(severity: .info),
        ]
        let report = makeReport(issues: issues)
        let output = RunReviewTool().format(report: report)
        #expect(output.contains("2 critical, 1 warnings, 1 info"))
    }

    @Test func formatListsFindings() {
        let issues = [makeIssue(severity: .warning, file: "auth.swift", line: 42,
                                description: "Empty catch", rationale: "swallows errors")]
        let report = makeReport(issues: issues)
        let output = RunReviewTool().format(report: report)
        #expect(output.contains("### Findings"))
        #expect(output.contains("`auth.swift:42`"))
        #expect(output.contains("Empty catch"))
        #expect(output.contains("Rationale: swallows errors"))
    }

    @Test func formatTruncatesBeyondTwelveFindings() {
        let issues = (0..<15).map { makeIssue(severity: .info, file: "f\($0).swift") }
        let report = makeReport(issues: issues)
        let output = RunReviewTool().format(report: report)
        // Footer should mention omitted findings beyond the first 12.
        #expect(output.contains("omitted") || output.contains("additional"))
    }
}
