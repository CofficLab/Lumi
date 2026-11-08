import Foundation
import KitAgentTool
import Testing
@testable import GitPlugin

/// `git_unpushed` 在缺少上游分支时不能报告“全部已推送”。
///
/// 没有 upstream 意味着不存在可比较的远程基准，状态必须是 `noUpstream`，
/// 与真正“本地没有领先提交”的 `upToDate` 区分开。
@Suite @MainActor struct GitUnpushedStateTests {

    // MARK: - Helpers

    private func runGit(_ args: [String], in url: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git"] + args
        process.currentDirectoryURL = url
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()
        #expect(process.terminationStatus == 0, "git \(args.joined(separator: " ")) 失败")
    }

    private func makeRepository(_ name: String) throws -> TestRepoFixture {
        let repo = TestRepoFixture(name: name)
        try repo.setUp()
        try repo.createFileAndCommit(name: "a.txt", content: "first", message: "init")
        return repo
    }

    private func makeBareRemote(_ name: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("GitPluginTests")
            .appendingPathComponent("\(name)-remote.git")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try runGit(["init", "--bare", "-q"], in: url)
        return url
    }

    // MARK: - Tests

    @Test("没有上游分支时返回 noUpstream，而不是 upToDate")
    func noUpstreamIsNotReportedAsPushed() async throws {
        let repo = try makeRepository("unpushed-no-upstream-\(UUID().uuidString)")
        defer { repo.cleanup() }

        let state = await GitService.shared.getUnpushedCommitsState(path: repo.repositoryPath)

        // 旧实现把“没有 upstream”折叠成空数组，这里会错误地得到 .upToDate。
        #expect(state == .noUpstream)
    }

    @Test("已推送且没有领先提交时返回 upToDate")
    func pushedBranchIsUpToDate() async throws {
        let name = "unpushed-up-to-date-\(UUID().uuidString)"
        let repo = try makeRepository(name)
        defer { repo.cleanup() }
        let remote = try makeBareRemote(name)
        defer { try? FileManager.default.removeItem(at: remote) }

        try runGit(["remote", "add", "origin", remote.path], in: repo.tempDirectory)
        try runGit(["push", "-u", "origin", "HEAD:refs/heads/main"], in: repo.tempDirectory)

        let state = await GitService.shared.getUnpushedCommitsState(path: repo.repositoryPath)

        #expect(state == .upToDate)
    }

    @Test("有上游且本地领先时返回未推送哈希")
    func aheadOfUpstreamReportsHashes() async throws {
        let name = "unpushed-ahead-\(UUID().uuidString)"
        let repo = try makeRepository(name)
        defer { repo.cleanup() }
        let remote = try makeBareRemote(name)
        defer { try? FileManager.default.removeItem(at: remote) }

        try runGit(["remote", "add", "origin", remote.path], in: repo.tempDirectory)
        try runGit(["push", "-u", "origin", "HEAD:refs/heads/main"], in: repo.tempDirectory)
        try repo.createFileAndCommit(name: "b.txt", content: "second", message: "second")

        let state = await GitService.shared.getUnpushedCommitsState(path: repo.repositoryPath)

        guard case .hasUnpushed(let hashes) = state else {
            Issue.record("期望 hasUnpushed，实际为 \(state)")
            return
        }
        #expect(hashes.count == 1)
    }

    @Test("路径不是 Git 仓库时返回 unavailable")
    func nonRepositoryIsUnavailable() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi-not-git-unpushed-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: url) }

        let state = await GitService.shared.getUnpushedCommitsState(path: url.path)

        #expect(state == .unavailable)
    }

    @Test("工具输出在无上游时给出明确提示")
    func toolExplainsMissingUpstream() async throws {
        let repo = try makeRepository("unpushed-tool-\(UUID().uuidString)")
        defer { repo.cleanup() }

        let tool = GitUnpushedV2Tool(project: nil)
        let output = try await tool.execute(arguments: ["path": ToolArgument(repo.repositoryPath)])

        #expect(output.contains("没有配置 upstream"))
        #expect(!output.contains("所有 commit 都已推送"))
    }
}
