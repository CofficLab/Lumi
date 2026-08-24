import Foundation
import LibGit2Swift
import Testing
@testable import GitPlugin

// MARK: - 简易测试仓库夹具

/// 使用 LibGit2 公开 API 自建的临时 git 仓库。
@MainActor
final class TestRepoFixture {
    let tempDirectory: URL
    let repositoryPath: String
    private var didInit = false

    init(name: String = "stash-\(UUID().uuidString)") {
        self.tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("GitPluginTests")
            .appendingPathComponent(name)
        self.repositoryPath = tempDirectory.path
    }

    func setUp() throws {
        try FileManager.default.createDirectory(
            at: tempDirectory, withIntermediateDirectories: true
        )
        LibGit2.initialize()
        _ = try LibGit2.createRepository(at: repositoryPath)
        try LibGit2.setConfig(key: "user.name", value: "Tester", at: repositoryPath, verbose: false)
        try LibGit2.setConfig(key: "user.email", value: "tester@example.com", at: repositoryPath, verbose: false)
        try LibGit2.setConfig(key: "init.defaultBranch", value: "main", at: repositoryPath, verbose: false)
        didInit = true
    }

    func createFileAndCommit(name: String, content: String, message: String) throws {
        precondition(didInit, "Call setUp() first")
        let url = tempDirectory.appendingPathComponent(name)
        try content.write(to: url, atomically: true, encoding: .utf8)
        try LibGit2.addFiles([name], at: repositoryPath)
        _ = try LibGit2.createCommit(message: message, at: repositoryPath, verbose: false)
    }

    func read(_ name: String) -> String {
        let url = tempDirectory.appendingPathComponent(name)
        return (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }

    func writeFile(_ name: String, content: String) throws {
        let url = tempDirectory.appendingPathComponent(name)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: tempDirectory)
    }
}

// MARK: - Stash 测试

@Suite @MainActor struct GitStashServiceTests {

    @Test func pushPopRoundTrip() throws {
        let repo = TestRepoFixture()
        try repo.setUp()
        defer { repo.cleanup() }

        try repo.createFileAndCommit(name: "a.txt", content: "first", message: "init")

        try repo.writeFile("a.txt", content: "second")
        let idx = try GitStashService.push(message: "WIP", at: repo.repositoryPath)
        #expect(idx == 0)
        #expect(GitStashService.exists(at: repo.repositoryPath))
        #expect(repo.read("a.txt") == "first")

        try GitStashService.pop(at: repo.repositoryPath)
        #expect(!GitStashService.exists(at: repo.repositoryPath))
        #expect(repo.read("a.txt") == "second")
    }

    @Test func pushWithNoChangesReturnsNil() throws {
        let repo = TestRepoFixture()
        try repo.setUp()
        defer { repo.cleanup() }
        try repo.createFileAndCommit(name: "a.txt", content: "x", message: "init")
        let idx = try GitStashService.push(at: repo.repositoryPath)
        #expect(idx == nil)
    }

    @Test func listAndCountMatch() throws {
        let repo = TestRepoFixture(name: "list-\(UUID().uuidString)")
        try repo.setUp()
        defer { repo.cleanup() }
        try repo.createFileAndCommit(name: "a.txt", content: "x", message: "init")

        #expect(GitStashService.count(at: repo.repositoryPath) == 0)

        try repo.writeFile("a.txt", content: "y")
        _ = try GitStashService.push(message: "one", at: repo.repositoryPath)

        #expect(GitStashService.count(at: repo.repositoryPath) == 1)
        let list = GitStashService.list(at: repo.repositoryPath)
        #expect(list.count == 1)
        #expect(list[0].message.contains("one"))
    }
}
