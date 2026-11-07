import Clibgit2
import Foundation
import XCTest
@testable import LibGit2Swift

/// 覆盖仓库状态判定与 merge-base 能力。
///
/// 这两项取代了宿主此前"探测 `.git/MERGE_HEAD` 文件"和"base 版本不支持"的
/// 权宜做法。
final class RepositoryStateTests: XCTestCase {
    private var root: URL!

    override func setUp() async throws {
        try await super.setUp()
        LibGit2.initialize()
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("LibGit2SwiftStateTests")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: root)
        LibGit2.shutdown()
        try await super.tearDown()
    }

    // MARK: - repositoryState

    func testCleanRepositoryReportsNone() throws {
        let repo = try makeRepository(named: "clean")
        try commit(in: repo, file: "a.txt", content: "a", message: "first")

        XCTAssertEqual(try LibGit2.repositoryState(at: repo.path), .none)
        XCTAssertFalse(try LibGit2.hasOperationInProgress(at: repo.path))
    }

    func testMergeConflictReportsMergeState() throws {
        let repo = try makeRepository(named: "merge-state")
        try commit(in: repo, file: "f.txt", content: "base", message: "base")

        // 构造一个必然冲突的合并。
        try runGit(["checkout", "-q", "-b", "side"], in: repo)
        try commit(in: repo, file: "f.txt", content: "side", message: "side change")
        try runGit(["checkout", "-q", "main"], in: repo)
        try commit(in: repo, file: "f.txt", content: "main", message: "main change")

        // merge 会因冲突而失败（退出码非 0），这是预期结果。
        _ = try? runGit(["merge", "side"], in: repo)

        let state = try LibGit2.repositoryState(at: repo.path)
        XCTAssertEqual(state, .merge)
        XCTAssertTrue(state.isMerge)
        XCTAssertTrue(state.isOperationInProgress)
        XCTAssertNotNil(state.userFacingDescription)
    }

    func testCherryPickInProgressReportsCherryPickState() throws {
        let repo = try makeRepository(named: "cherry-state")
        try commit(in: repo, file: "f.txt", content: "base", message: "base")
        let base = try head(in: repo)

        try runGit(["checkout", "-q", "-b", "side"], in: repo)
        try commit(in: repo, file: "f.txt", content: "side", message: "side change")
        let side = try head(in: repo)

        // 回到 base 并制造冲突性改动，使 cherry-pick 停在中间状态。
        try runGit(["checkout", "-q", "main"], in: repo)
        try runGit(["reset", "-q", "--hard", base], in: repo)
        try commit(in: repo, file: "f.txt", content: "main", message: "main change")

        _ = try? runGit(["cherry-pick", side], in: repo)

        let state = try LibGit2.repositoryState(at: repo.path)
        XCTAssertTrue(state.isCherryPick, "expected cherry-pick state, got \(state)")
    }

    func testRevertInProgressReportsRevertState() throws {
        let repo = try makeRepository(named: "revert-state")
        try commit(in: repo, file: "f.txt", content: "base", message: "base")
        let second = try commit(in: repo, file: "f.txt", content: "second", message: "second")
        try commit(in: repo, file: "f.txt", content: "third", message: "third")

        // revert 早先的提交会与之后的改动冲突，从而停在中间状态。
        _ = try? runGit(["revert", "--no-edit", second], in: repo)

        let state = try LibGit2.repositoryState(at: repo.path)
        XCTAssertTrue(state.isRevert, "expected revert state, got \(state)")
    }

    func testBisectReportsBisectState() throws {
        let repo = try makeRepository(named: "bisect-state")
        try commit(in: repo, file: "a.txt", content: "1", message: "c1")
        try commit(in: repo, file: "a.txt", content: "2", message: "c2")
        try commit(in: repo, file: "a.txt", content: "3", message: "c3")

        try runGit(["bisect", "start"], in: repo)
        try runGit(["bisect", "bad", "HEAD"], in: repo)
        try runGit(["bisect", "good", "HEAD~2"], in: repo)

        XCTAssertEqual(try LibGit2.repositoryState(at: repo.path), .bisect)
    }

    /// worktree 中 `.git` 是文件而非目录，探测 `.git/MERGE_HEAD` 会失败。
    /// `repositoryState` 必须仍然正确。
    func testRepositoryStateWorksInLinkedWorktree() throws {
        let repo = try makeRepository(named: "worktree-main")
        try commit(in: repo, file: "a.txt", content: "a", message: "first")

        let worktreePath = root.appendingPathComponent("worktree-linked")
        try runGit(["worktree", "add", "-b", "wt-branch", worktreePath.path], in: repo)

        // 确认该 worktree 的 .git 确实是文件。
        let dotGit = worktreePath.appendingPathComponent(".git")
        var isDirectory: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: dotGit.path, isDirectory: &isDirectory))
        XCTAssertFalse(isDirectory.boolValue, "linked worktree .git should be a file")

        XCTAssertEqual(try LibGit2.repositoryState(at: worktreePath.path), .none)
    }

    // MARK: - merge base

    func testMergeBaseFindsCommonAncestor() throws {
        let repo = try makeRepository(named: "merge-base")
        let base = try commit(in: repo, file: "a.txt", content: "base", message: "base")

        try runGit(["checkout", "-q", "-b", "side"], in: repo)
        let side = try commit(in: repo, file: "b.txt", content: "side", message: "side")

        try runGit(["checkout", "-q", "main"], in: repo)
        let main = try commit(in: repo, file: "c.txt", content: "main", message: "main")

        XCTAssertEqual(try LibGit2.mergeBase(between: side, and: main, at: repo.path), base)
        XCTAssertEqual(try LibGit2.mergeBase(between: main, and: base, at: repo.path), base)
    }

    func testMergeBaseReturnsNilForUnrelatedHistories() throws {
        let first = try makeRepository(named: "unrelated-a")
        try commit(in: first, file: "a.txt", content: "a", message: "a")
        let firstHead = try head(in: first)

        let second = try makeRepository(named: "unrelated-b")
        try commit(in: second, file: "b.txt", content: "b", message: "b")
        let secondHead = try head(in: second)

        // 把两个不相关历史放进同一个仓库来比较。
        let combined = try makeRepository(named: "combined")
        try runGit(["fetch", first.path, "main:refs/heads/other-a"], in: combined)
        try runGit(["fetch", second.path, "main:refs/heads/other-b"], in: combined)

        XCTAssertNil(try LibGit2.mergeBase(between: firstHead, and: secondHead, at: combined.path))
    }

    /// 冲突时 `base` 版本文件内容应可读取（此前 provider 对此抛"不支持"）。
    func testMergeBaseFileContentDuringConflict() throws {
        let repo = try makeRepository(named: "merge-base-content")
        try commit(in: repo, file: "f.txt", content: "base content", message: "base")

        try runGit(["checkout", "-q", "-b", "side"], in: repo)
        try commit(in: repo, file: "f.txt", content: "side content", message: "side")
        try runGit(["checkout", "-q", "main"], in: repo)
        try commit(in: repo, file: "f.txt", content: "main content", message: "main")

        _ = try? runGit(["merge", "side"], in: repo)
        XCTAssertEqual(try LibGit2.repositoryState(at: repo.path), .merge)

        // base 版本即双方共同祖先的内容。
        XCTAssertEqual(
            try LibGit2.mergeBaseFileContent(path: "f.txt", at: repo.path),
            "base content"
        )
    }

    func testMergeBaseFileContentIsNilWithoutMergeInProgress() throws {
        let repo = try makeRepository(named: "merge-base-no-merge")
        try commit(in: repo, file: "f.txt", content: "content", message: "only")

        // 没有 MERGE_HEAD 时无 base 可言。
        XCTAssertNil(try LibGit2.mergeBaseFileContent(path: "f.txt", at: repo.path))
    }

    // MARK: - 脚手架

    private func makeRepository(named name: String) throws -> URL {
        let url = root.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try runGit(["init", "--initial-branch=main", url.path], in: root)
        try runGit(["config", "user.name", "Test User"], in: url)
        try runGit(["config", "user.email", "test@example.com"], in: url)
        return url
    }

    @discardableResult
    private func commit(in repo: URL, file: String, content: String, message: String) throws -> String {
        try content.write(
            to: repo.appendingPathComponent(file),
            atomically: true,
            encoding: .utf8
        )
        try runGit(["add", file], in: repo)
        try runGit(["commit", "-m", message], in: repo)
        return try head(in: repo)
    }

    private func head(in repo: URL) throws -> String {
        try runGit(["rev-parse", "HEAD"], in: repo)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @discardableResult
    private func runGit(_ arguments: [String], in directory: URL) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = arguments
        process.currentDirectoryURL = directory

        let output = Pipe()
        let error = Pipe()
        process.standardOutput = output
        process.standardError = error

        try process.run()
        process.waitUntilExit()

        let outputData = output.fileHandleForReading.readDataToEndOfFile()
        let errorData = error.fileHandleForReading.readDataToEndOfFile()

        guard process.terminationStatus == 0 else {
            throw NSError(
                domain: "RepositoryStateTests.git",
                code: Int(process.terminationStatus),
                userInfo: [
                    NSLocalizedDescriptionKey: String(data: errorData, encoding: .utf8) ?? "git failed",
                ]
            )
        }
        return String(data: outputData, encoding: .utf8) ?? ""
    }
}
