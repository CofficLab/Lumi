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
            staged: ["a.swift"],
            untracked: ["new.txt"]
        )
        // 去重（a.swift 同时出现在 modified 与 staged）+ 含 untracked，按字典序排序。
        #expect(status.allChangedFiles == ["a.swift", "b.swift", "c.swift", "new.txt"])
    }

    @Test func workingChangesSynthesizesStagedAndUntracked() {
        // staged 优先：a.swift 既在 modified 又在 staged → isStaged=true，state=.modified。
        // 仅在 staged 的 e.swift → isStaged=true，state=.modified（无具体 state 时用 modified 兜底）。
        // 未暂存的修改/新增/删除/重命名/未跟踪 → isStaged=false，state 对应。
        let status = GitStatus(
            branch: "main",
            remote: nil,
            modified: ["a.swift", "b.swift"],
            added: ["c.swift"],
            deleted: ["d.swift"],
            renamed: ["old.swift"],
            staged: ["a.swift", "e.swift"],
            untracked: ["f.txt"]
        )
        let changes = Dictionary(uniqueKeysWithValues: status.workingChanges().map { ($0.path, $0) })

        #expect(changes["a.swift"]?.state == .modified)
        #expect(changes["a.swift"]?.isStaged == true)
        #expect(changes["b.swift"]?.state == .modified)
        #expect(changes["b.swift"]?.isStaged == false)
        #expect(changes["c.swift"]?.state == .added)
        #expect(changes["c.swift"]?.isStaged == false)
        #expect(changes["d.swift"]?.state == .deleted)
        #expect(changes["e.swift"]?.state == .modified)
        #expect(changes["e.swift"]?.isStaged == true)
        #expect(changes["old.swift"]?.state == .renamed)
        #expect(changes["f.txt"]?.state == .untracked)
        #expect(changes["f.txt"]?.isStaged == false)
        // 按路径排序。
        #expect(status.workingChanges().map(\.path) == ["a.swift", "b.swift", "c.swift", "d.swift", "e.swift", "f.txt", "old.swift"])
    }

    @Test func modelsRoundTripThroughCodable() throws {
        let status = GitStatus(
            branch: "dev",
            remote: nil,
            modified: ["x.swift"],
            untracked: ["y.txt"]
        )
        let restored = try JSONDecoder().decode(
            GitStatus.self,
            from: JSONEncoder().encode(status)
        )
        #expect(restored == status)
        #expect(restored.untracked == ["y.txt"])

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

    /// 旧版 GitStatus JSON 不含 untracked 字段，应降级为空数组而非解码失败。
    @Test func gitStatusDecodeToleratesMissingUntracked() throws {
        let legacyJSON = """
        {
          "branch": "main",
          "remote": "origin/main",
          "modified": ["a.swift"],
          "added": [],
          "deleted": [],
          "renamed": [],
          "staged": []
        }
        """
        let status = try JSONDecoder().decode(
            GitStatus.self,
            from: Data(legacyJSON.utf8)
        )
        #expect(status.branch == "main")
        #expect(status.modified == ["a.swift"])
        #expect(status.untracked == [])
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

    @Test func inMemoryImplementationServesCommitChangesAndIsRepository() async throws {
        let git = InMemoryGitRepositoryReading()
        git.addRepository(atPath: "/repo")

        // isRepository 仅在显式注册路径返回 true。
        #expect(await git.isRepository(atPath: "/repo") == true)
        #expect(await git.isRepository(atPath: "/other") == false)
        #expect(await git.isRepository(atPath: nil) == false)

        let changes: [GitCommitChange] = [
            GitCommitChange(path: "a.swift", state: .modified),
            GitCommitChange(path: "b.swift", state: .added),
        ]
        git.setCommitChanges(changes, forPath: "/repo", hash: "abc123")
        let fetched = try await git.commitChanges(atPath: "/repo", hash: "abc123")
        #expect(fetched.count == 2)
        #expect(fetched.map(\.path) == ["a.swift", "b.swift"])

        // 未知 hash 报 repositoryNotFound。
        await #expect(throws: GitReadError.self) {
            _ = try await git.commitChanges(atPath: "/repo", hash: "missing")
        }
    }
}
