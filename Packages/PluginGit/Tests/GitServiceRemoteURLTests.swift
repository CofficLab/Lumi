import Foundation
import Testing
@testable import GitPlugin

/// `GitService.remoteURL(atPath:remote:)` 在真实 Git 仓库上的行为。
///
/// 契约要求：返回**原始 remote URL**（不做任何协议转换），
/// 读取失败时返回 `nil` 而不抛错。
@Suite("GitService 远程地址读取")
struct GitServiceRemoteURLTests {

    // MARK: - Helpers

    /// 创建临时 Git 仓库并返回其路径。
    private func makeRepository() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi-git-remote-\(UUID().uuidString)")
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

    // MARK: - Tests

    @Test("读取 origin 的远程地址并保持原始写法")
    func readsOriginRemoteURLVerbatim() async throws {
        let repo = try makeRepository()
        defer { try? FileManager.default.removeItem(at: repo) }

        try runGit(["remote", "add", "origin", "git@github.com:user/repo.git"], in: repo)

        let url = await GitService.shared.remoteURL(atPath: repo.path, remote: "origin")

        // 契约层不做协议转换：scp-like 写法原样返回。
        #expect(url == "git@github.com:user/repo.git")
    }

    @Test("读取指定名称的远程地址")
    func readsNamedRemoteURL() async throws {
        let repo = try makeRepository()
        defer { try? FileManager.default.removeItem(at: repo) }

        try runGit(["remote", "add", "origin", "git@github.com:user/repo.git"], in: repo)
        try runGit(["remote", "add", "upstream", "https://github.com/user/upstream.git"], in: repo)

        let upstream = await GitService.shared.remoteURL(atPath: repo.path, remote: "upstream")

        #expect(upstream == "https://github.com/user/upstream.git")
    }

    @Test("不存在的远程名称返回 nil")
    func returnsNilForUnknownRemote() async throws {
        let repo = try makeRepository()
        defer { try? FileManager.default.removeItem(at: repo) }

        let url = await GitService.shared.remoteURL(atPath: repo.path, remote: "origin")

        #expect(url == nil)
    }

    @Test("非仓库目录与不存在的路径返回 nil 且不抛错")
    func returnsNilForNonRepositoryPaths() async throws {
        let nonRepo = FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi-not-git-remote-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: nonRepo, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: nonRepo) }

        let missing = "/tmp/lumi-missing-remote-\(UUID().uuidString)"

        #expect(await GitService.shared.remoteURL(atPath: nonRepo.path, remote: "origin") == nil)
        #expect(await GitService.shared.remoteURL(atPath: missing, remote: "origin") == nil)
    }
}
