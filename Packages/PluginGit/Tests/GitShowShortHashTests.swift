import Foundation
import LibGit2Swift
import Testing
@testable import GitPlugin

/// `git_show` 必须能吃下 `git_log` 展示的 7 位短哈希。
@Suite @MainActor struct GitShowShortHashTests {

    @Test("短哈希可查到 commit 详情与变更文件")
    func shortHashResolvesDetailAndChangedFiles() async throws {
        let fixture = TestRepoFixture(name: "show-short-\(UUID().uuidString)")
        try fixture.setUp()
        defer { fixture.cleanup() }
        try fixture.createFileAndCommit(name: "notes.md", content: "hello\n", message: "add notes")

        let log = try await GitService.shared.getLog(
            path: fixture.repositoryPath,
            count: 10,
            branch: nil,
            file: nil
        )
        let fullHash = try #require(log.first?.hash)
        let shortHash = String(fullHash.prefix(7))
        #expect(shortHash.count == 7)

        let detail = try await GitService.shared.getCommitDetail(
            path: fixture.repositoryPath,
            hash: shortHash
        )
        #expect(detail.hash == fullHash)
        #expect(detail.message == "add notes")

        let files = try await GitService.shared.getCommitChangedFiles(
            path: fixture.repositoryPath,
            hash: shortHash
        )
        #expect(files.map(\.path) == ["notes.md"])
    }

    @Test("无法匹配的短哈希仍然报错")
    func unknownShortHashStillThrows() async throws {
        let fixture = TestRepoFixture(name: "show-unknown-\(UUID().uuidString)")
        try fixture.setUp()
        defer { fixture.cleanup() }
        try fixture.createFileAndCommit(name: "notes.md", content: "hello\n", message: "add notes")

        let missing = String(repeating: "0", count: 7)
        await #expect(throws: (any Error).self) {
            _ = try await GitService.shared.getCommitDetail(
                path: fixture.repositoryPath,
                hash: missing
            )
        }
    }
}
