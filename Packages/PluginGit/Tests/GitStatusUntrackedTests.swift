import Foundation
import KitAgentTool
import Testing
@testable import GitPlugin

/// `git_status` 必须把未跟踪文件呈现为工作区变更，且仅存在未跟踪文件时
/// 不得报告「工作区干净」（#155）。
@Suite @MainActor struct GitStatusUntrackedTests {

    @Test("仅有未跟踪文件时不得报告工作区干净")
    func untrackedOnlyChangeIsNotReportedClean() async throws {
        let repo = TestRepoFixture(name: "status-untracked-only-\(UUID().uuidString)")
        try repo.setUp()
        defer { repo.cleanup() }
        try repo.createFileAndCommit(name: "tracked.txt", content: "x", message: "init")
        try repo.writeFile("new-file.txt", content: "loose")

        let output = try await GitStatusV2Tool().execute(arguments: ["path": ToolArgument(repo.repositoryPath)])

        #expect(output.contains("new-file.txt"))
        #expect(output.contains("未跟踪的文件"))
        #expect(!output.contains("工作区干净"))
    }

    @Test("未跟踪文件与其它变更一并列出")
    func untrackedListedAlongsideOtherChanges() async throws {
        let repo = TestRepoFixture(name: "status-untracked-mixed-\(UUID().uuidString)")
        try repo.setUp()
        defer { repo.cleanup() }
        try repo.createFileAndCommit(name: "tracked.txt", content: "x", message: "init")
        try repo.writeFile("tracked.txt", content: "changed")
        try repo.writeFile("new-file.txt", content: "loose")

        let output = try await GitStatusV2Tool().execute(arguments: ["path": ToolArgument(repo.repositoryPath)])

        #expect(output.contains("修改的文件"))
        #expect(output.contains("未跟踪的文件"))
        #expect(output.contains("new-file.txt"))
        #expect(!output.contains("工作区干净"))
    }

    @Test("真正干净的仓库仍报告工作区干净（无回归）")
    func genuinelyCleanRepoStillReportsClean() async throws {
        let repo = TestRepoFixture(name: "status-clean-\(UUID().uuidString)")
        try repo.setUp()
        defer { repo.cleanup() }
        try repo.createFileAndCommit(name: "tracked.txt", content: "x", message: "init")

        let output = try await GitStatusV2Tool().execute(arguments: ["path": ToolArgument(repo.repositoryPath)])

        #expect(output.contains("工作区干净"))
        #expect(!output.contains("未跟踪的文件"))
    }
}