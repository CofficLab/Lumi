import Foundation
import LibGit2Swift
import Testing
@testable import GitPlugin

/// 当前分支读取失败必须抛出，不能伪装成 detached HEAD（#915）。
@Suite @MainActor struct GitBranchReadFailureTests {

    @Test("HEAD 指向不存在的分支引用时 currentBranch 抛出而非返回 nil")
    func unreadableCurrentBranchThrowsInsteadOfReturningNil() async throws {
        let fixture = TestRepoFixture(name: "broken-head-\(UUID().uuidString)")
        try fixture.setUp()
        defer { fixture.cleanup() }
        try fixture.createFileAndCommit(name: "notes.md", content: "hello\n", message: "add notes")

        let provider = GitBranchProvider()
        #expect(await provider.isRepository(atPath: fixture.repositoryPath))
        #expect(try await provider.currentBranch(atPath: fixture.repositoryPath) != nil)

        // HEAD 仍是符号引用（所以不是 detached HEAD），但目标分支不存在。
        let headURL = fixture.tempDirectory.appendingPathComponent(".git/HEAD")
        try "ref: refs/heads/missing-branch\n".write(to: headURL, atomically: true, encoding: .utf8)

        // 分支列表独立遍历 refs，此时仍能读到有效分支；因此故障只能由
        // currentBranch 自己暴露，若被折叠成 nil 就会被当成 detached HEAD。
        let branches = try await provider.listBranches(atPath: fixture.repositoryPath, includeRemote: false)
        #expect(!branches.isEmpty)

        await #expect(throws: LibGit2Error.self) {
            _ = try await provider.currentBranch(atPath: fixture.repositoryPath)
        }
    }
}
