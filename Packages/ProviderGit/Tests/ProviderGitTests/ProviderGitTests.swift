import Foundation
import Testing
@testable import ProviderGit

@Suite("ProviderGit")
struct ProviderGitTests {

    // MARK: - Models

    @Test func statusCollectsAllChangedFiles() {
        let status = GitStatus(
            branch: "main",
            remote: "origin/main",
            modified: ["b.swift", "a.swift"],
            added: ["c.swift"],
            deleted: [],
            renamed: [],
            staged: ["a.swift"]
        )
        // 去重（a.swift 同时出现在 modified 与 staged）并按字典序排序。
        #expect(status.allChangedFiles == ["a.swift", "b.swift", "c.swift"])
    }

    @Test func modelsRoundTripThroughCodable() throws {
        let status = GitStatus(branch: "dev", remote: nil, modified: ["x.swift"])
        let restored = try JSONDecoder().decode(
            GitStatus.self,
            from: JSONEncoder().encode(status)
        )
        #expect(restored == status)

        let commit = GitCommitLog(
            hash: "abc123",
            author: "nookery",
            email: "nooks@qq.com",
            date: "2026-09-16T05:26:39Z",
            message: "feat: something"
        )
        let restoredCommit = try JSONDecoder().decode(
            GitCommitLog.self,
            from: JSONEncoder().encode(commit)
        )
        #expect(restoredCommit == commit)
    }

    // MARK: - Date parsing

    @Test func parsesISO8601CommitDates() throws {
        let date = try #require(GitDateFormatting.date(from: "2026-09-16T05:26:39Z"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        #expect(parts.year == 2026)
        #expect(parts.month == 9)
        #expect(parts.day == 16)
    }

    @Test func parsesFallbackDateFormats() {
        // formatHandlers 覆盖的两种非 ISO 写法。
        #expect(GitDateFormatting.date(from: "2026-09-16 05:26:39 +0000") != nil)
        #expect(GitDateFormatting.date(from: "2026-09-16 05:26:39") != nil)
        #expect(GitDateFormatting.date(from: "not a date") == nil)
    }

    // MARK: - In-memory implementation

    @Test func inMemoryImplementationServesStatusAndLog() async throws {
        let git = InMemoryGitRepositoryReading()
        let commits = (1...5).map {
            GitCommitLog(hash: "h\($0)", author: "a", email: "e", date: "2026-09-16T00:00:00Z", message: "m\($0)")
        }
        git.setCommits(commits, forPath: "/repo")
        git.setStatus(GitStatus(branch: "main", remote: nil, modified: ["f.swift"]), forPath: "/repo")

        let status = try await git.status(atPath: "/repo")
        #expect(status.branch == "main")

        // 分页：skip 2 / count 2 → 第 3、4 条。
        let page = try await git.log(atPath: "/repo", count: 2, skip: 2)
        #expect(page.map(\.hash) == ["h3", "h4"])

        // 越界 skip 返回空而不是崩溃。
        let beyond = try await git.log(atPath: "/repo", count: 2, skip: 99)
        #expect(beyond.isEmpty)

        // 便捷重载走同一份数据。
        let recent = try await git.recentCommits(atPath: "/repo", count: 10)
        #expect(recent.count == 5)
    }

    @Test func inMemoryImplementationReportsUnknownRepository() async {
        let git = InMemoryGitRepositoryReading()
        await #expect(throws: GitReadError.self) {
            _ = try await git.status(atPath: "/missing")
        }
        // nil 路径同样报错而不是返回空状态。
        await #expect(throws: GitReadError.self) {
            _ = try await git.status(atPath: nil)
        }
    }
}
