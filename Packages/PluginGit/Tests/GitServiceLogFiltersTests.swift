import Foundation
import LibGit2Swift
import Testing
@testable import GitPlugin

/// `git_log` 的 branch / file 过滤必须真实生效（#154）。
///
/// 旧实现把两个参数原样传进 `GitService.getLog` 后直接丢弃，无论传什么
/// 都返回当前 HEAD 的历史 —— 分支查询结果错误且无任何报错。
@Suite @MainActor struct GitServiceLogFiltersTests {

    /// 构造分叉历史：
    ///
    /// - `main`：`init`（shared.txt）→ `main commit`（main.txt）
    /// - `feature-x`（从 init 分出）：`init`（shared.txt）→ `feature commit`（feature.txt）
    private func makeDivergedRepo(_ name: String) throws -> TestRepoFixture {
        let repo = TestRepoFixture(name: name)
        try repo.setUp()
        try repo.createFileAndCommit(name: "shared.txt", content: "s0", message: "init")

        _ = try LibGit2.createBranch(named: "feature-x", at: repo.repositoryPath, checkout: true)
        try repo.createFileAndCommit(name: "feature.txt", content: "f1", message: "feature commit")

        try LibGit2.checkout(branch: "main", at: repo.repositoryPath, verbose: false)
        try repo.createFileAndCommit(name: "main.txt", content: "m1", message: "main commit")
        return repo
    }

    @Test("branch 参数返回该分支的历史，而不是当前 HEAD 的历史")
    func branchParameterFiltersHistory() async throws {
        let repo = try makeDivergedRepo("gitlog-branch-\(UUID().uuidString)")
        defer { repo.cleanup() }

        let headLog = try await GitService.shared.getLog(
            path: repo.repositoryPath, count: 10, branch: nil, file: nil)
        let branchLog = try await GitService.shared.getLog(
            path: repo.repositoryPath, count: 10, branch: "feature-x", file: nil)

        #expect(headLog.map(\.message) == ["main commit", "init"])
        #expect(branchLog.map(\.message) == ["feature commit", "init"],
                "branch=feature-x 必须返回 feature-x 的历史（#154）")
        #expect(!branchLog.contains { $0.message == "main commit" })
    }

    @Test("file 参数只返回触碰该文件的提交")
    func fileParameterFiltersHistory() async throws {
        let repo = try makeDivergedRepo("gitlog-file-\(UUID().uuidString)")
        defer { repo.cleanup() }

        let log = try await GitService.shared.getLog(
            path: repo.repositoryPath, count: 10, branch: nil, file: "main.txt")

        #expect(log.map(\.message) == ["main commit"],
                "file=main.txt 必须只返回触碰该文件的提交（#154）")

        // 根提交与空树比较：init 创建了 shared.txt，必须被检索到。
        let rootLog = try await GitService.shared.getLog(
            path: repo.repositoryPath, count: 10, branch: nil, file: "shared.txt")
        #expect(rootLog.map(\.message) == ["init"])
    }

    @Test("branch 与 file 可以组合过滤")
    func branchAndFileCombine() async throws {
        let repo = try makeDivergedRepo("gitlog-branch-file-\(UUID().uuidString)")
        defer { repo.cleanup() }

        let log = try await GitService.shared.getLog(
            path: repo.repositoryPath, count: 10, branch: "feature-x", file: "feature.txt")

        #expect(log.map(\.message) == ["feature commit"])
    }

    @Test("不存在的 branch 必须报错，而不是静默回落成 HEAD 历史")
    func unknownBranchThrows() async throws {
        let repo = try makeDivergedRepo("gitlog-badbranch-\(UUID().uuidString)")
        defer { repo.cleanup() }

        await #expect(throws: (any Error).self) {
            _ = try await GitService.shared.getLog(
                path: repo.repositoryPath, count: 10, branch: "no-such-branch", file: nil)
        }
    }
}
