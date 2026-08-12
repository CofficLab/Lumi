import Foundation
import Testing
import LibGit2Swift
@testable import GitPlugin

@Suite @MainActor struct GitSubmoduleServiceTests {

    @Test func submoduleListReturnsEmptyForRepoWithoutSubmodules() throws {
        let repo = TestRepoFixture(name: "sub-\(UUID().uuidString)")
        try repo.setUp()
        defer { repo.cleanup() }
        try repo.createFileAndCommit(name: "a.txt", content: "x", message: "init")
        let list = GitSubmoduleService.list(at: repo.repositoryPath)
        #expect(list.isEmpty)
        #expect(!GitSubmoduleService.hasSubmodules(at: repo.repositoryPath))
    }
}
