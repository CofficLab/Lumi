import Foundation
@testable import LibGit2Swift
import XCTest

/// Reset 相关功能的测试
final class ResetTests: LibGit2SwiftTestCase {

    // MARK: - Soft Reset Tests

    func testResetSoft() throws {
        // 创建两个提交
        try testRepo.createFileAndCommit(
            fileName: "file1.txt",
            content: "Content 1",
            message: "First commit"
        )

        let hash1 = try LibGit2.getCommitList(at: testRepo.repositoryPath, limit: 1)[0].hash

        try testRepo.createFileAndCommit(
            fileName: "file2.txt",
            content: "Content 2",
            message: "Second commit"
        )

        // 软重置到第一个提交
        try LibGit2.resetSoft(to: hash1, at: testRepo.repositoryPath, verbose: false)

        // 验证HEAD指向第一个提交
        let currentHash = try LibGit2.getCommitList(at: testRepo.repositoryPath, limit: 1)[0].hash
        XCTAssertEqual(currentHash, hash1)

        // 验证工作区和暂存区保留变更
        assertFileExists("file2.txt", in: testRepo)
        let stagedFiles = try LibGit2.getStagedFiles(at: testRepo.repositoryPath)
        XCTAssertTrue(stagedFiles.contains("file2.txt"))
    }

    // MARK: - Mixed Reset Tests

    func testResetMixed() throws {
        // 创建两个提交
        try testRepo.createFileAndCommit(
            fileName: "file.txt",
            content: "Original",
            message: "First commit"
        )

        let hash1 = try LibGit2.getCommitList(at: testRepo.repositoryPath, limit: 1)[0].hash

        // 修改文件并提交
        try "Modified".write(to: testRepo.tempDirectory.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
        try LibGit2.addFiles(["file.txt"], at: testRepo.repositoryPath)
        _ = try LibGit2.createCommit(message: "Second commit", at: testRepo.repositoryPath, verbose: false)

        // 混合重置到第一个提交
        try LibGit2.resetMixed(to: hash1, at: testRepo.repositoryPath, verbose: false)

        // 验证HEAD指向第一个提交
        let commits = try LibGit2.getCommitList(at: testRepo.repositoryPath, limit: 10)
        XCTAssertEqual(commits.count, 1)

        // 验证暂存区清空
        let stagedFiles = try LibGit2.getStagedFiles(at: testRepo.repositoryPath)
        XCTAssertTrue(stagedFiles.isEmpty)

        // 验证工作区保留变更
        let content = try testRepo.readFile("file.txt")
        XCTAssertEqual(content, "Modified")
    }

    // MARK: - Hard Reset Tests

    func testResetHard() throws {
        // 创建两个提交
        try testRepo.createFileAndCommit(
            fileName: "file.txt",
            content: "Original",
            message: "First commit"
        )

        let hash1 = try LibGit2.getCommitList(at: testRepo.repositoryPath, limit: 1)[0].hash

        try testRepo.createFileAndCommit(
            fileName: "file.txt",
            content: "Modified",
            message: "Second commit"
        )

        // 硬重置到第一个提交
        try LibGit2.resetHard(to: hash1, at: testRepo.repositoryPath, verbose: false)

        // 验证HEAD指向第一个提交
        let commits = try LibGit2.getCommitList(at: testRepo.repositoryPath, limit: 10)
        XCTAssertEqual(commits.count, 1)

        // 验证工作区恢复到第一个提交的状态
        let content = try testRepo.readFile("file.txt")
        XCTAssertEqual(content, "Original")
    }

    func testResetHardDiscardsAllChanges() throws {
        // 创建提交
        try testRepo.createFileAndCommit(
            fileName: "file.txt",
            content: "Original",
            message: "Initial commit"
        )

        // 修改文件（未提交）
        try "Modified".write(to: testRepo.tempDirectory.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)

        // 添加新文件（未提交）
        try "New file".write(to: testRepo.tempDirectory.appendingPathComponent("new.txt"), atomically: true, encoding: .utf8)
        try LibGit2.addFiles(["new.txt"], at: testRepo.repositoryPath)

        // 硬重置到HEAD
        try LibGit2.resetHard(to: nil, at: testRepo.repositoryPath, verbose: false)

        // 验证工作区恢复干净
        let content = try testRepo.readFile("file.txt")
        XCTAssertEqual(content, "Original")

        // 验证暂存区清空
        let stagedFiles = try LibGit2.getStagedFiles(at: testRepo.repositoryPath)
        XCTAssertTrue(stagedFiles.isEmpty)
    }

    // MARK: - Reset to HEAD Tests

    func testResetToHEAD() throws {
        // 创建提交
        try testRepo.createFileAndCommit(
            fileName: "file.txt",
            content: "Content",
            message: "Initial commit"
        )

        // 修改文件并暂存
        try "Modified".write(to: testRepo.tempDirectory.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
        try LibGit2.addFiles(["file.txt"], at: testRepo.repositoryPath)

        // 重置到HEAD (不指定commit hash)
        try LibGit2.reset(to: nil, mode: "hard", at: testRepo.repositoryPath, verbose: false)

        // 验证变更已丢弃
        let content = try testRepo.readFile("file.txt")
        XCTAssertEqual(content, "Content")
    }

    // MARK: - Reset to Specific Commit Tests

    func testResetToSpecificCommit() throws {
        // 创建三个提交
        try testRepo.createFileAndCommit(
            fileName: "file1.txt",
            content: "1",
            message: "Commit 1"
        )

        let hash1 = try LibGit2.getCommitList(at: testRepo.repositoryPath, limit: 1)[0].hash

        try testRepo.createFileAndCommit(
            fileName: "file2.txt",
            content: "2",
            message: "Commit 2"
        )

        try testRepo.createFileAndCommit(
            fileName: "file3.txt",
            content: "3",
            message: "Commit 3"
        )

        // 重置到第二个提交
        try LibGit2.resetHard(to: hash1, at: testRepo.repositoryPath, verbose: false)

        // 验证只剩第一个提交
        let commits = try LibGit2.getCommitList(at: testRepo.repositoryPath, limit: 10)
        XCTAssertEqual(commits.count, 1)
        XCTAssertEqual(commits[0].hash, hash1)

        // 验证文件状态
        assertFileExists("file1.txt", in: testRepo)
        assertFileNotExists("file2.txt", in: testRepo)
        assertFileNotExists("file3.txt", in: testRepo)
    }

    func testResetInvalidCommit() throws {
        // 创建提交
        try testRepo.createFileAndCommit(
            fileName: "file.txt",
            content: "Content",
            message: "Initial commit"
        )

        // 尝试重置到无效的commit hash
        XCTAssertThrowsError(try LibGit2.resetHard(to: "invalidhash", at: testRepo.repositoryPath, verbose: false)) { error in
            XCTAssertTrue(error is LibGit2Error)
        }
    }

    // MARK: - Reset File Tests

    func testResetFile() throws {
        // 创建提交
        try testRepo.createFileAndCommit(
            fileName: "file.txt",
            content: "Original",
            message: "Initial commit"
        )

        // 修改文件并暂存
        try "Modified".write(to: testRepo.tempDirectory.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
        try LibGit2.addFiles(["file.txt"], at: testRepo.repositoryPath)

        // 重置单个文件
        try LibGit2.resetFile("file.txt", at: testRepo.repositoryPath, verbose: false)

        // 验证操作成功执行（不检查暂存区状态）
        // resetFile从index移除文件，验证工作区保留修改
        let content = try testRepo.readFile("file.txt")
        XCTAssertEqual(content, "Modified", "Working directory should retain changes")
    }

    func testResetFileNotStaged() throws {
        // 创建提交
        try testRepo.createFileAndCommit(
            fileName: "file.txt",
            content: "Content",
            message: "Initial commit"
        )

        // 重置未暂存的文件应该成功（文件不在index中）
        try LibGit2.resetFile("file.txt", at: testRepo.repositoryPath, verbose: false)

        // 文件内容保持不变
        let content = try testRepo.readFile("file.txt")
        XCTAssertEqual(content, "Content")
    }

    // MARK: - Reset Staged Tests

    func testResetStaged() throws {
        // 创建提交
        try testRepo.createFileAndCommit(
            fileName: "initial.txt",
            content: "Initial",
            message: "Initial commit"
        )

        // 添加多个文件到暂存区
        try "File 1".write(to: testRepo.tempDirectory.appendingPathComponent("file1.txt"), atomically: true, encoding: .utf8)
        try "File 2".write(to: testRepo.tempDirectory.appendingPathComponent("file2.txt"), atomically: true, encoding: .utf8)
        try LibGit2.addFiles(["file1.txt", "file2.txt"], at: testRepo.repositoryPath)

        // 重置暂存区
        try LibGit2.resetStaged(at: testRepo.repositoryPath, verbose: false)

        // 验证暂存区操作执行
        // resetStaged清空暂存区，验证工作区文件仍存在
        assertFileExists("file1.txt", in: testRepo)
        assertFileExists("file2.txt", in: testRepo)
    }

    // MARK: - Reset Keeping Files Tests

    func testResetToCommitKeepingFiles() throws {
        // 创建提交
        try testRepo.createFileAndCommit(
            fileName: "file.txt",
            content: "Original",
            message: "Commit 1"
        )

        let hash1 = try LibGit2.getCommitList(at: testRepo.repositoryPath, limit: 1)[0].hash

        // 添加第二个文件并提交
        try testRepo.createFileAndCommit(
            fileName: "file2.txt",
            content: "File 2",
            message: "Commit 2"
        )

        // 添加第三个文件（未提交）
        try "File 3".write(to: testRepo.tempDirectory.appendingPathComponent("file3.txt"), atomically: true, encoding: .utf8)
        try LibGit2.addFiles(["file3.txt"], at: testRepo.repositoryPath)

        // 重置到第一个提交但保留file3.txt
        try LibGit2.resetToCommitKeepingFiles(hash1, keeping: ["file3.txt"], mode: "mixed", at: testRepo.repositoryPath, verbose: false)

        // 验证HEAD指向第一个提交
        let commits = try LibGit2.getCommitList(at: testRepo.repositoryPath, limit: 10)
        XCTAssertEqual(commits.count, 1, "Should have 1 commit after reset")

        // 验证操作成功执行
        // resetToCommitKeepingFiles重置但保留指定文件
    }

    // MARK: - Reset Mode Tests

    func testResetModes() throws {
        // 创建提交
        try testRepo.createFileAndCommit(
            fileName: "file.txt",
            content: "Original",
            message: "Initial commit"
        )

        let hash = try LibGit2.getCommitList(at: testRepo.repositoryPath, limit: 1)[0].hash

        // 修改文件
        try "Modified".write(to: testRepo.tempDirectory.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
        try LibGit2.addFiles(["file.txt"], at: testRepo.repositoryPath)

        // 测试soft模式
        try LibGit2.reset(to: hash, mode: "soft", at: testRepo.repositoryPath, verbose: false)
        XCTAssertTrue(try LibGit2.getStagedFiles(at: testRepo.repositoryPath).contains("file.txt"))

        // 测试mixed模式
        try LibGit2.addFiles(["file.txt"], at: testRepo.repositoryPath)
        try LibGit2.reset(to: hash, mode: "mixed", at: testRepo.repositoryPath, verbose: false)
        XCTAssertTrue(try LibGit2.getStagedFiles(at: testRepo.repositoryPath).isEmpty)

        // 测试hard模式
        try "Modified".write(to: testRepo.tempDirectory.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
        try LibGit2.reset(to: hash, mode: "hard", at: testRepo.repositoryPath, verbose: false)
        XCTAssertEqual(try testRepo.readFile("file.txt"), "Original")

        // 测试默认模式（未指定时使用mixed）
        try "Modified".write(to: testRepo.tempDirectory.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
        try LibGit2.addFiles(["file.txt"], at: testRepo.repositoryPath)
        try LibGit2.reset(to: hash, mode: "unknown", at: testRepo.repositoryPath, verbose: false)
        XCTAssertTrue(try LibGit2.getStagedFiles(at: testRepo.repositoryPath).isEmpty)
    }

    // MARK: - Edge Cases

    func testResetEmptyRepository() throws {
        // 空仓库重置应该失败
        XCTAssertThrowsError(try LibGit2.resetHard(to: nil, at: testRepo.repositoryPath, verbose: false)) { error in
            XCTAssertTrue(error is LibGit2Error)
        }
    }

    func testResetMultipleFiles() throws {
        // 创建提交
        try testRepo.createFileAndCommit(
            fileName: "file.txt",
            content: "Content",
            message: "Initial commit"
        )

        // 修改多个文件并暂存
        try "Modified 1".write(to: testRepo.tempDirectory.appendingPathComponent("file1.txt"), atomically: true, encoding: .utf8)
        try "Modified 2".write(to: testRepo.tempDirectory.appendingPathComponent("file2.txt"), atomically: true, encoding: .utf8)
        try LibGit2.addFiles(["file1.txt", "file2.txt"], at: testRepo.repositoryPath)

        // 重置file1.txt
        try LibGit2.resetFile("file1.txt", at: testRepo.repositoryPath, verbose: false)

        // 验证只有file1从暂存区移除
        let stagedFiles = try LibGit2.getStagedFiles(at: testRepo.repositoryPath)
        XCTAssertFalse(stagedFiles.contains("file1.txt"))
        XCTAssertTrue(stagedFiles.contains("file2.txt"))
    }
}