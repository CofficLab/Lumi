import Foundation
import ProviderGit
import Testing
@testable import PluginGitWorkspace

@MainActor
@Suite(.serialized)
struct GitWorkspaceViewModelTests {
    @Test func loadsStatusAndRecentCommitsForCurrentProject() async throws {
        let status = try makeStatus(
            branch: "main",
            modified: ["README.md", "z.txt"],
            added: ["README.md", "shared.txt"],
            staged: ["shared.txt"]
        )
        let commits = try makeCommits([("abc123", "Initial commit")])
        let git = StubGitWorkspaceGitProvider(statuses: ["/project": status], commits: ["/project": commits])
        let viewModel = GitWorkspaceViewModel(git: git)

        await viewModel.reload(path: "/project")

        #expect(viewModel.status?.branch == "main")
        #expect(viewModel.status?.modified == ["README.md", "z.txt"])
        #expect(viewModel.commits.map(\.hash) == ["abc123"])
        #expect(viewModel.workingTreeFiles == ["README.md", "shared.txt", "z.txt"])
        #expect(viewModel.changeLabel(for: "shared.txt") == "S")
        #expect(viewModel.changeLabel(for: "README.md") == "A")
        #expect(viewModel.changeLabel(for: "z.txt") == "M")
        #expect(!viewModel.isLoading)
        #expect(viewModel.errorMessage == nil)
        let requests = await git.requests()
        #expect(requests.statusPaths == ["/project"])
        #expect(requests.logRequests == [.init(path: "/project", count: 50, branch: nil, file: nil)])
    }

    @Test func reportsGitErrorsAndClearsStateWhenProjectIsRemoved() async throws {
        let status = try makeStatus(branch: "main", modified: [])
        let git = StubGitWorkspaceGitProvider(
            statuses: ["/project": status],
            statusFailures: ["/broken"]
        )
        let viewModel = GitWorkspaceViewModel(git: git)

        await viewModel.reload(path: "/broken")
        #expect(viewModel.errorMessage == StubGitWorkspaceError.status.localizedDescription)
        #expect(!viewModel.isLoading)

        await viewModel.reload(path: "/project")
        #expect(viewModel.status?.branch == "main")
        #expect(viewModel.errorMessage == nil)

        await viewModel.reload(path: nil)
        #expect(viewModel.status == nil)
        #expect(viewModel.commits.isEmpty)
        #expect(viewModel.errorMessage == nil)
        #expect(!viewModel.isLoading)
    }

    @Test func aNewProjectSupersedesAnInFlightRequestAndSamePathReloadIsDeduplicated() async throws {
        let slowStatus = try makeStatus(branch: "slow", modified: ["old.txt"])
        let fastStatus = try makeStatus(branch: "fast", modified: ["new.txt"])
        let slowCommits = try makeCommits([("slow-hash", "Old project")])
        let fastCommits = try makeCommits([("fast-hash", "New project")])
        let git = StubGitWorkspaceGitProvider(
            statuses: ["/slow": slowStatus, "/fast": fastStatus],
            commits: ["/slow": slowCommits, "/fast": fastCommits],
            suspendedStatusPaths: ["/slow"]
        )
        let viewModel = GitWorkspaceViewModel(git: git)
        let slowLoad = Task { await viewModel.reload(path: "/slow") }
        await waitUntil { await git.isStatusWaiting(path: "/slow") }

        await viewModel.reload(path: "/slow")
        let beforeSwitch = await git.requests()
        #expect(beforeSwitch.statusPaths == ["/slow"])
        #expect(beforeSwitch.logRequests.count == 1)

        await viewModel.reload(path: "/fast")
        #expect(viewModel.status?.branch == "fast")
        #expect(viewModel.commits.map(\.hash) == ["fast-hash"])
        await git.resumeStatus(path: "/slow")
        await slowLoad.value

        #expect(viewModel.status?.branch == "fast")
        #expect(viewModel.commits.map(\.hash) == ["fast-hash"])
        #expect(!viewModel.isLoading)
    }

    @Test func includesUntrackedFilesInWorkingTree() async throws {
        let status = try makeStatus(
            branch: "main",
            modified: ["README.md"],
            untracked: ["new-file.txt", "another.txt"]
        )
        let git = StubGitWorkspaceGitProvider(statuses: ["/project": status])
        let viewModel = GitWorkspaceViewModel(git: git)

        await viewModel.reload(path: "/project")

        #expect(viewModel.workingTreeFiles == ["README.md", "another.txt", "new-file.txt"])
        #expect(viewModel.changeLabel(for: "new-file.txt") == "?")
        #expect(viewModel.changeLabel(for: "README.md") == "M")
    }

    /// 回归 #1283：大变更集下标签与排序仍正确，且工作树列表可稳定重复读取
    /// （缓存而非每次 body 重建）。
    @Test func largeWorkingTreeKeepsCorrectLabelsAndOrdering() async throws {
        let modified = (0..<2000).map { "f\($0).txt" }
        let status = try makeStatus(
            branch: "main",
            modified: modified,
            added: ["added.txt"],
            deleted: ["deleted.txt"],
            staged: ["staged.txt"]
        )
        let git = StubGitWorkspaceGitProvider(statuses: ["/project": status])
        let viewModel = GitWorkspaceViewModel(git: git)

        await viewModel.reload(path: "/project")

        #expect(viewModel.workingTreeFiles.count == 2003)
        #expect(viewModel.workingTreeFiles == viewModel.workingTreeFiles.sorted())
        #expect(viewModel.changeLabel(for: "f1999.txt") == "M")
        #expect(viewModel.changeLabel(for: "added.txt") == "A")
        #expect(viewModel.changeLabel(for: "deleted.txt") == "D")
        #expect(viewModel.changeLabel(for: "staged.txt") == "S")

        // 重复读取应返回同一缓存内容，不再每次重建。
        let first = viewModel.workingTreeFiles
        for _ in 0..<50 {
            #expect(viewModel.workingTreeFiles == first)
        }
    }

    /// 回归 #1283：文件同时出现在多个分类时，标签优先级与原先一致。
    @Test func labelPrecedenceMatchesCategoryPriority() async throws {
        let status = try makeStatus(
            branch: "main",
            modified: ["all.txt", "added.txt", "deleted.txt", "renamed.txt", "untracked.txt", "modified.txt"],
            added: ["all.txt", "added.txt"],
            deleted: ["all.txt", "deleted.txt"],
            renamed: ["all.txt", "renamed.txt"],
            staged: ["all.txt"],
            untracked: ["all.txt", "untracked.txt"]
        )
        let git = StubGitWorkspaceGitProvider(statuses: ["/project": status])
        let viewModel = GitWorkspaceViewModel(git: git)

        await viewModel.reload(path: "/project")

        #expect(viewModel.changeLabel(for: "all.txt") == "S")
        #expect(viewModel.changeLabel(for: "added.txt") == "A")
        #expect(viewModel.changeLabel(for: "deleted.txt") == "D")
        #expect(viewModel.changeLabel(for: "renamed.txt") == "R")
        #expect(viewModel.changeLabel(for: "untracked.txt") == "?")
        #expect(viewModel.changeLabel(for: "modified.txt") == "M")
    }

    /// 回归 #1283：移除项目后缓存的工作树与标签必须清空。
    @Test func clearingProjectResetsCachedWorkingTree() async throws {
        let status = try makeStatus(branch: "main", modified: ["a.txt"], added: ["b.txt"])
        let git = StubGitWorkspaceGitProvider(statuses: ["/project": status])
        let viewModel = GitWorkspaceViewModel(git: git)

        await viewModel.reload(path: "/project")
        #expect(viewModel.workingTreeFiles == ["a.txt", "b.txt"])

        await viewModel.reload(path: nil)
        #expect(viewModel.workingTreeFiles.isEmpty)
        #expect(viewModel.changeLabel(for: "a.txt") == "?")
    }

    /// 回归 #389：切换项目时必须先丢弃上一个项目的数据，否则新项目
    /// 加载失败时旧仓库的分支、变更与提交会顶着新项目的标题继续展示。
    @Test func switchingToAnotherProjectClearsStaleDataOnFailure() async throws {
        let status = try makeStatus(branch: "main", modified: ["a.txt"])
        let commits = try makeCommits([("abc123", "Initial commit")])
        let git = StubGitWorkspaceGitProvider(
            statuses: ["/repo-a": status],
            commits: ["/repo-a": commits],
            statusFailures: ["/plain"]
        )
        let viewModel = GitWorkspaceViewModel(git: git)

        await viewModel.reload(path: "/repo-a")
        #expect(viewModel.status?.branch == "main")
        #expect(viewModel.commits.map(\.hash) == ["abc123"])

        await viewModel.reload(path: "/plain")
        #expect(viewModel.status == nil)
        #expect(viewModel.commits.isEmpty)
        #expect(viewModel.workingTreeFiles.isEmpty)
        #expect(viewModel.errorMessage == StubGitWorkspaceError.status.localizedDescription)
    }

    /// 回归 #389：同路径刷新不应清空已有数据（避免面板闪烁）。
    @Test func samePathReloadKeepsLoadedDataUntilReplaced() async throws {
        let status = try makeStatus(branch: "main", modified: ["a.txt"])
        let commits = try makeCommits([("abc123", "Initial commit")])
        let git = StubGitWorkspaceGitProvider(statuses: ["/repo-a": status], commits: ["/repo-a": commits])
        let viewModel = GitWorkspaceViewModel(git: git)

        await viewModel.reload(path: "/repo-a")

        await viewModel.reload(path: "/repo-a", force: true)
        #expect(viewModel.status?.branch == "main")
        #expect(viewModel.commits.map(\.hash) == ["abc123"])
        #expect(viewModel.errorMessage == nil)
    }

    private func makeStatus(
        branch: String,
        modified: [String],
        added: [String] = [],
        deleted: [String] = [],
        renamed: [String] = [],
        staged: [String] = [],
        untracked: [String] = []
    ) throws -> GitStatus {
        let object: [String: Any] = [
            "branch": branch,
            "remote": "origin/\(branch)",
            "modified": modified,
            "added": added,
            "deleted": deleted,
            "renamed": renamed,
            "staged": staged,
            "untracked": untracked,
        ]
        return try JSONDecoder().decode(GitStatus.self, from: JSONSerialization.data(withJSONObject: object))
    }

    private func makeCommits(_ entries: [(String, String)]) throws -> [GitCommitLog] {
        try entries.map { hash, message in
            let object: [String: String] = [
                "hash": hash,
                "author": "Test Author",
                "email": "test@example.com",
                "date": "2026-09-12T00:00:00Z",
                "message": message,
            ]
            return try JSONDecoder().decode(GitCommitLog.self, from: JSONSerialization.data(withJSONObject: object))
        }
    }

    private func waitUntil(_ condition: () async -> Bool) async {
        for _ in 0..<100 {
            if await condition() { return }
            await Task.yield()
        }
    }
}

private enum StubGitWorkspaceError: LocalizedError, Sendable {
    case status
    case log

    var errorDescription: String? {
        switch self {
        case .status: "status unavailable"
        case .log: "log unavailable"
        }
    }
}

private actor StubGitWorkspaceGitProvider: GitWorkspaceGitProviding {
    struct LogRequest: Equatable, Sendable {
        let path: String
        let count: Int
        let branch: String?
        let file: String?
    }

    struct RequestSnapshot: Sendable {
        let statusPaths: [String]
        let logRequests: [LogRequest]
    }

    private let statuses: [String: GitStatus]
    private let commits: [String: [GitCommitLog]]
    private let statusFailures: Set<String>
    private let logFailures: Set<String>
    private var suspendedStatusPaths: Set<String>
    private var statusContinuations: [String: CheckedContinuation<GitStatus, any Error>] = [:]
    private var statusPaths: [String] = []
    private var logRequests: [LogRequest] = []

    init(
        statuses: [String: GitStatus] = [:],
        commits: [String: [GitCommitLog]] = [:],
        statusFailures: Set<String> = [],
        logFailures: Set<String> = [],
        suspendedStatusPaths: Set<String> = []
    ) {
        self.statuses = statuses
        self.commits = commits
        self.statusFailures = statusFailures
        self.logFailures = logFailures
        self.suspendedStatusPaths = suspendedStatusPaths
    }

    func getStatus(path: String) async throws -> GitStatus {
        statusPaths.append(path)
        if suspendedStatusPaths.contains(path) {
            return try await withCheckedThrowingContinuation { statusContinuations[path] = $0 }
        }
        if statusFailures.contains(path) { throw StubGitWorkspaceError.status }
        guard let status = statuses[path] else { throw StubGitWorkspaceError.status }
        return status
    }

    func getLog(path: String, count: Int, branch: String?, file: String?) async throws -> [GitCommitLog] {
        logRequests.append(LogRequest(path: path, count: count, branch: branch, file: file))
        if logFailures.contains(path) { throw StubGitWorkspaceError.log }
        return commits[path] ?? []
    }

    func isStatusWaiting(path: String) -> Bool {
        statusContinuations[path] != nil
    }

    func resumeStatus(path: String) {
        suspendedStatusPaths.remove(path)
        guard let continuation = statusContinuations.removeValue(forKey: path) else { return }
        if let status = statuses[path] {
            continuation.resume(returning: status)
        } else {
            continuation.resume(throwing: StubGitWorkspaceError.status)
        }
    }

    func requests() -> RequestSnapshot {
        RequestSnapshot(statusPaths: statusPaths, logRequests: logRequests)
    }
}
