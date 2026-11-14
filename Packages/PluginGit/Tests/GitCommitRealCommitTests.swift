import Foundation
import LibGit2Swift
import Testing
@testable import GitPlugin

/// #176 真实提交回归：用 LibGit2 自建临时仓库 + 同名前缀兄弟目录，
/// 端到端验证 `GitService.commit` 的路径边界处理。
///
/// 旧 `GitCommitToolPathTests` 声称「沙箱无法测试 LibGit2 commit」已过时——
/// 本包 `GitStashServiceTests` 等已在 swift test 中真实运行 LibGit2。
@Suite("GitCommit 真实提交路径边界测试")
struct GitCommitRealCommitTests {

    private func makeRepo(at repoURL: URL) throws {
        try FileManager.default.createDirectory(at: repoURL, withIntermediateDirectories: true)
        LibGit2.initialize()
        _ = try LibGit2.createRepository(at: repoURL.path)
        try LibGit2.setConfig(key: "user.name", value: "Tester", at: repoURL.path, verbose: false)
        try LibGit2.setConfig(key: "user.email", value: "tester@example.com", at: repoURL.path, verbose: false)
    }

    private func write(_ url: URL, _ content: String) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    private func tempRepo(_ label: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("GitPluginTests/commit176-\(label)-\(UUID().uuidString)")
            .appendingPathComponent("App")
    }

    @Test("仓库外同名前缀路径必须抛错且不得提交任何内部文件")
    func outOfRepoSiblingPrefixPathIsRejectedAndCommitsNothing() async throws {
        let repoURL = tempRepo("sibling")
        let parent = repoURL.deletingLastPathComponent()
        let siblingURL = parent.appendingPathComponent("App-old")
        defer { try? FileManager.default.removeItem(at: parent) }
        try makeRepo(at: repoURL)
        try FileManager.default.createDirectory(at: siblingURL, withIntermediateDirectories: true)

        // 仓库内 -old/file.txt：外部 /App-old/file.txt 经裸 hasPrefix 会被误映射成它。
        // 先提交 v1，再制造未提交的 v2 修改：若 bug 存在，v2 会被错误地 stage+commit。
        let internalFile = repoURL.appendingPathComponent("-old/file.txt")
        try write(internalFile, "v1")
        try LibGit2.addFiles(["-old/file.txt"], at: repoURL.path, verbose: false)
        _ = try LibGit2.createCommit(message: "seed internal", at: repoURL.path, verbose: false)
        try write(internalFile, "v2-uncommitted")

        // 用户真正指定的目标：仓库外的兄弟目录文件。
        let externalFile = siblingURL.appendingPathComponent("file.txt")
        try write(externalFile, "external")

        let headBefore = try LibGit2.headCommitHash(at: repoURL.path)
        #expect(headBefore != nil, "种子提交应存在")

        await #expect(throws: GitServiceError.self) {
            _ = try await GitService.shared.commit(
                path: repoURL.path,
                message: "should not commit",
                files: [externalFile.path],
                amend: false
            )
        }

        let headAfter = try LibGit2.headCommitHash(at: repoURL.path)
        #expect(headBefore == headAfter, "仓库外路径被拒绝后 HEAD 不得前进（不得提交内部 -old/file.txt）")
    }

    @Test("仓库内绝对路径提交正确的文件")
    func absolutePathInsideRepoCommitsCorrectFile() async throws {
        let repoURL = tempRepo("abs")
        let parent = repoURL.deletingLastPathComponent()
        defer { try? FileManager.default.removeItem(at: parent) }
        try makeRepo(at: repoURL)

        let file = repoURL.appendingPathComponent("a.txt")
        try write(file, "v1")
        try LibGit2.addFiles(["a.txt"], at: repoURL.path, verbose: false)
        _ = try LibGit2.createCommit(message: "seed", at: repoURL.path, verbose: false)
        try write(file, "v2")
        let headBefore = try LibGit2.headCommitHash(at: repoURL.path)

        let result = try await GitService.shared.commit(
            path: repoURL.path,
            message: "update a",
            files: [file.path],
            amend: false
        )

        let headAfter = try LibGit2.headCommitHash(at: repoURL.path)
        #expect(headAfter != headBefore, "提交后 HEAD 应前进")
        #expect(result.hash == headAfter, "返回的 hash 应为新 HEAD")
        #expect(result.changedFiles.contains("a.txt"), "变更文件应为仓库内相对路径 a.txt")
    }

    @Test("仓库内相对路径按 git 约定提交")
    func relativePathInsideRepoCommits() async throws {
        let repoURL = tempRepo("rel")
        let parent = repoURL.deletingLastPathComponent()
        defer { try? FileManager.default.removeItem(at: parent) }
        try makeRepo(at: repoURL)

        let file = repoURL.appendingPathComponent("b.txt")
        try write(file, "v1")
        try LibGit2.addFiles(["b.txt"], at: repoURL.path, verbose: false)
        _ = try LibGit2.createCommit(message: "seed", at: repoURL.path, verbose: false)
        try write(file, "v2")
        let headBefore = try LibGit2.headCommitHash(at: repoURL.path)

        let result = try await GitService.shared.commit(
            path: repoURL.path,
            message: "update b",
            files: ["b.txt"],
            amend: false
        )

        let headAfter = try LibGit2.headCommitHash(at: repoURL.path)
        #expect(headAfter != headBefore, "相对路径提交后 HEAD 应前进")
        #expect(result.changedFiles.contains("b.txt"), "变更文件应为 b.txt")
    }
}
