import Foundation
import Testing
@testable import GitPlugin

/// 真实 Git 仓库上的只读契约行为。
///
/// 覆盖 ``GitService`` 对 ``GitRepositoryReading`` 的实现：
/// - `getStatus` 把未跟踪文件分流到 `untracked`（而非 `modified`）；
/// - `isRepository(atPath:)` 对仓库/非仓库目录给出正确判定且不抛错；
/// - `commitChanges(atPath:hash:)` 返回该 commit 的变更文件与状态。
@Suite("GitService 读取契约")
struct GitServiceReadingContractTests {

    // MARK: - Helpers

    /// 创建临时 Git 仓库并返回其路径。
    private func makeRepository() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi-git-contract-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try runGit(["init", "-q"], in: url)
        try runGit(["config", "user.email", "test@example.com"], in: url)
        try runGit(["config", "user.name", "Test"], in: url)
        return url
    }

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

    private func write(_ contents: String, to name: String, in url: URL) throws {
        let fileURL = url.appendingPathComponent(name)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try contents.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    // MARK: - Tests

    @Test("getStatus 把未跟踪文件分流到 untracked")
    func statusSeparatesUntrackedFiles() async throws {
        let repo = try makeRepository()
        defer { try? FileManager.default.removeItem(at: repo) }

        try write("tracked\n", to: "tracked.txt", in: repo)
        try runGit(["add", "tracked.txt"], in: repo)
        try runGit(["commit", "-q", "-m", "init"], in: repo)

        // 修改已跟踪文件 + 新增未跟踪文件 + 新增已暂存文件。
        try write("changed\n", to: "tracked.txt", in: repo)
        try write("loose\n", to: "untracked.txt", in: repo)
        try write("staged\n", to: "staged.txt", in: repo)
        try runGit(["add", "staged.txt"], in: repo)

        let status = try await GitService.shared.getStatus(path: repo.path)

        #expect(status.untracked.contains("untracked.txt"))
        #expect(!status.modified.contains("untracked.txt"))
        #expect(status.modified.contains("tracked.txt"))
        #expect(status.staged.contains("staged.txt"))
    }

    @Test("isRepository 对仓库与非仓库目录判定正确")
    func isRepositoryDetectsRepository() async throws {
        let repo = try makeRepository()
        defer { try? FileManager.default.removeItem(at: repo) }

        let nonRepo = FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi-not-git-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: nonRepo, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: nonRepo) }

        let isRepo = await GitService.shared.isRepository(atPath: repo.path)
        let isNonRepo = await GitService.shared.isRepository(atPath: nonRepo.path)

        #expect(isRepo == true)
        #expect(isNonRepo == false)
    }

    @Test("isRepository 对不存在的路径返回 false 且不抛错")
    func isRepositoryToleratesMissingPath() async throws {
        let missing = "/tmp/lumi-missing-\(UUID().uuidString)"
        let result = await GitService.shared.isRepository(atPath: missing)
        #expect(result == false)
    }

    @Test("commitChanges 返回该 commit 的变更文件")
    func commitChangesReturnsFiles() async throws {
        let repo = try makeRepository()
        defer { try? FileManager.default.removeItem(at: repo) }

        try write("one\n", to: "a.txt", in: repo)
        try runGit(["add", "a.txt"], in: repo)
        try runGit(["commit", "-q", "-m", "first"], in: repo)

        try write("two\n", to: "b.txt", in: repo)
        try runGit(["add", "b.txt"], in: repo)
        try runGit(["commit", "-q", "-m", "second"], in: repo)

        let log = try await GitService.shared.getLog(path: repo.path, count: 1, branch: nil, file: nil)
        let head = try #require(log.first)

        let changes = try await GitService.shared.commitChanges(atPath: repo.path, hash: head.hash)

        #expect(changes.contains { $0.path == "b.txt" })
        #expect(changes.contains { $0.path == "b.txt" && $0.state == .added })
    }
}
