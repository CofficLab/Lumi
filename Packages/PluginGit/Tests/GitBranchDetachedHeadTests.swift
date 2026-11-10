import Foundation
import LibGit2Swift
import Testing
@testable import GitPlugin

/// detached HEAD 不能被当成分支名展示。
@Suite @MainActor struct GitBranchDetachedHeadTests {

    @Test("detached HEAD 时 currentBranch 为 nil，提交哈希由独立接口提供")
    func detachedHeadIsNotReportedAsBranch() async throws {
        let fixture = TestRepoFixture(name: "detached-\(UUID().uuidString)")
        try fixture.setUp()
        defer { fixture.cleanup() }
        try fixture.createFileAndCommit(name: "notes.md", content: "hello\n", message: "add notes")

        let provider = GitBranchProvider()
        let branchBefore = try #require(
            try await provider.currentBranch(atPath: fixture.repositoryPath)
        )
        #expect(try await provider.detachedHeadCommitHash(atPath: fixture.repositoryPath) == nil)

        let log = try await GitService.shared.getLog(
            path: fixture.repositoryPath,
            count: 10,
            branch: nil,
            file: nil
        )
        let fullHash = try #require(log.first?.hash)
        try LibGit2.checkoutCommit(fullHash, at: fixture.repositoryPath)

        // 关键断言：detached 时不能再把 40 位 OID 当作分支名。
        #expect(try await provider.currentBranch(atPath: fixture.repositoryPath) == nil)
        #expect(try await provider.detachedHeadCommitHash(atPath: fixture.repositoryPath) == fullHash)

        try LibGit2.checkout(branch: branchBefore, at: fixture.repositoryPath)
        #expect(try await provider.currentBranch(atPath: fixture.repositoryPath) == branchBefore)
        #expect(try await provider.detachedHeadCommitHash(atPath: fixture.repositoryPath) == nil)
    }
}
