import Foundation
@testable import LibGit2Swift
import XCTest

/// Stash 相关功能的测试
final class StashTests: LibGit2SwiftTestCase {

    // MARK: - Basic Stash Tests

    func testStashChanges() throws {
        // 创建初始提交
        try testRepo.createFileAndCommit(
            fileName: "initial.txt",
            content: "Initial content",
            message: "Initial commit"
        )

        // 修改文件
        let fileURL = testRepo.tempDirectory.appendingPathComponent("initial.txt")
        try "Modified content".write(to: fileURL, atomically: true, encoding: .utf8)

        // 暂存变更
        let stashIndex = try LibGit2.stash(at: testRepo.repositoryPath, verbose: false)

        // 验证返回了有效的索引
        XCTAssertEqual(stashIndex, 0, "First stash should have index 0")

        // 验证工作区已恢复到原始状态
        let content = try testRepo.readFile("initial.txt")
        XCTAssertEqual(content, "Initial content", "File should be restored to original state after stash")

        // 验证有暂存记录
        XCTAssertTrue(try LibGit2.hasStash(at: testRepo.repositoryPath))
    }

    func testStashWithMessage() throws {
        // 创建初始提交
        try testRepo.createFileAndCommit(
            fileName: "file.txt",
            content: "Content",
            message: "Initial commit"
        )

        // 修改文件
        let fileURL = testRepo.tempDirectory.appendingPathComponent("file.txt")
        try "New content".write(to: fileURL, atomically: true, encoding: .utf8)

        // 暂存变更并指定消息
        let message = "WIP: Testing stash message"
        let stashIndex = try LibGit2.stash(message: message, at: testRepo.repositoryPath, verbose: false)

        XCTAssertEqual(stashIndex, 0)

        // 验证暂存列表中包含消息
        let stashList = try LibGit2.getStashList(at: testRepo.repositoryPath)
        XCTAssertEqual(stashList.count, 1)
        XCTAssertTrue(stashList[0].message.contains("Testing stash message"))
    }

    func testStashNoChanges() throws {
        // 创建初始提交
        try testRepo.createFileAndCommit(
            fileName: "file.txt",
            content: "Content",
            message: "Initial commit"
        )

        // 没有变更时暂存
        let stashIndex = try LibGit2.stash(at: testRepo.repositoryPath, verbose: false)

        // 验证返回 -1 表示没有变更
        XCTAssertEqual(stashIndex, -1, "Stash with no changes should return -1")

        // 验证没有暂存记录
        XCTAssertFalse(try LibGit2.hasStash(at: testRepo.repositoryPath))
    }

    func testStashMultipleChanges() throws {
        // 创建初始提交
        try testRepo.createFileAndCommit(
            fileName: "file1.txt",
            content: "Content 1",
            message: "Initial commit"
        )

        // 第一次修改和暂存
        try "Modified 1".write(to: testRepo.tempDirectory.appendingPathComponent("file1.txt"), atomically: true, encoding: .utf8)
        _ = try LibGit2.stash(message: "First change", at: testRepo.repositoryPath, verbose: false)

        // 第二次修改和暂存
        try "Modified 2".write(to: testRepo.tempDirectory.appendingPathComponent("file1.txt"), atomically: true, encoding: .utf8)
        let secondIndex = try LibGit2.stash(message: "Second change", at: testRepo.repositoryPath, verbose: false)

        XCTAssertEqual(secondIndex, 0, "Newest stash should have index 0")

        // 验证暂存数量
        let count = try LibGit2.getStashCount(at: testRepo.repositoryPath)
        XCTAssertEqual(count, 2)
    }

    // MARK: - Stash Pop Tests

    func testStashPop() throws {
        // 创建初始提交
        try testRepo.createFileAndCommit(
            fileName: "file.txt",
            content: "Original",
            message: "Initial commit"
        )

        // 修改并暂存
        try "Modified".write(to: testRepo.tempDirectory.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
        _ = try LibGit2.stash(at: testRepo.repositoryPath, verbose: false)

        // 恢复暂存
        try LibGit2.stashPop(at: testRepo.repositoryPath, verbose: false)

        // 验证文件已恢复修改
        let content = try testRepo.readFile("file.txt")
        XCTAssertEqual(content, "Modified", "File should be restored to stashed state")

        // 验证暂存已从列表删除
        XCTAssertFalse(try LibGit2.hasStash(at: testRepo.repositoryPath))
    }

    func testStashPopSpecificIndex() throws {
        // 创建多次暂存
        try testRepo.createFileAndCommit(
            fileName: "file.txt",
            content: "Original",
            message: "Initial commit"
        )

        try "Change 1".write(to: testRepo.tempDirectory.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
        _ = try LibGit2.stash(message: "Stash 1", at: testRepo.repositoryPath, verbose: false)

        try "Change 2".write(to: testRepo.tempDirectory.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
        _ = try LibGit2.stash(message: "Stash 2", at: testRepo.repositoryPath, verbose: false)

        // 恢复最新的暂存(index 0)
        try LibGit2.stashPop(index: 0, at: testRepo.repositoryPath, verbose: false)

        // 验证恢复的是最新的变更
        let content = try testRepo.readFile("file.txt")
        XCTAssertEqual(content, "Change 2")

        // 验证剩下一个暂存
        XCTAssertEqual(try LibGit2.getStashCount(at: testRepo.repositoryPath), 1)
    }

    // MARK: - Stash Apply Tests

    func testStashApply() throws {
        // 创建初始提交
        try testRepo.createFileAndCommit(
            fileName: "file.txt",
            content: "Original",
            message: "Initial commit"
        )

        // 修改并暂存
        try "Modified".write(to: testRepo.tempDirectory.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
        _ = try LibGit2.stash(at: testRepo.repositoryPath, verbose: false)

        // 应用暂存（不删除）
        try LibGit2.stashApply(at: testRepo.repositoryPath, verbose: false)

        // 验证文件已恢复
        let content = try testRepo.readFile("file.txt")
        XCTAssertEqual(content, "Modified")

        // 验证暂存仍存在于列表中
        XCTAssertTrue(try LibGit2.hasStash(at: testRepo.repositoryPath))
    }

    func testStashApplySpecificIndex() throws {
        // 创建多次暂存
        try testRepo.createFileAndCommit(
            fileName: "file.txt",
            content: "Original",
            message: "Initial commit"
        )

        try "Change 1".write(to: testRepo.tempDirectory.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
        _ = try LibGit2.stash(message: "Stash 1", at: testRepo.repositoryPath, verbose: false)

        try "Change 2".write(to: testRepo.tempDirectory.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
        _ = try LibGit2.stash(message: "Stash 2", at: testRepo.repositoryPath, verbose: false)

        // 应用较早的暂存(index 1)
        try LibGit2.stashApply(index: 1, at: testRepo.repositoryPath, verbose: false)

        // 验证恢复的是较早的变更
        let content = try testRepo.readFile("file.txt")
        XCTAssertEqual(content, "Change 1")

        // 验证暂存列表不变
        XCTAssertEqual(try LibGit2.getStashCount(at: testRepo.repositoryPath), 2)
    }

    // MARK: - Stash List Tests

    func testGetStashList() throws {
        // 创建初始提交
        try testRepo.createFileAndCommit(
            fileName: "file.txt",
            content: "Content",
            message: "Initial commit"
        )

        // 空仓库应该没有暂存列表
        let emptyList = try LibGit2.getStashList(at: testRepo.repositoryPath)
        XCTAssertTrue(emptyList.isEmpty)

        // 创建多个暂存
        try "Change 1".write(to: testRepo.tempDirectory.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
        _ = try LibGit2.stash(message: "First stash", at: testRepo.repositoryPath, verbose: false)

        try "Change 2".write(to: testRepo.tempDirectory.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
        _ = try LibGit2.stash(message: "Second stash", at: testRepo.repositoryPath, verbose: false)

        // 获取暂存列表
        let stashList = try LibGit2.getStashList(at: testRepo.repositoryPath)
        XCTAssertEqual(stashList.count, 2, "Should have 2 stashes")

        // 验证暂存列表包含正确的消息
        if stashList.count >= 2 {
            XCTAssertTrue(stashList[0].message.contains("stash") || stashList[1].message.contains("stash"))
        }
    }

    func testGetStashListMessages() throws {
        // 创建初始提交
        try testRepo.createFileAndCommit(
            fileName: "file.txt",
            content: "Content",
            message: "Initial commit"
        )

        // 创建暂存并检查消息
        try "Modified".write(to: testRepo.tempDirectory.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
        _ = try LibGit2.stash(message: "Feature work in progress", at: testRepo.repositoryPath, verbose: false)

        let stashList = try LibGit2.getStashList(at: testRepo.repositoryPath)
        XCTAssertEqual(stashList.count, 1)

        // 验证消息被正确解析
        let stashInfo = stashList[0]
        XCTAssertTrue(stashInfo.message.contains("Feature work"))
        XCTAssertFalse(stashInfo.commitHash.isEmpty, "Commit hash should not be empty")
    }

    // MARK: - Stash Drop Tests

    func testStashDrop() throws {
        // 创建多个暂存
        try testRepo.createFileAndCommit(
            fileName: "file.txt",
            content: "Original",
            message: "Initial commit"
        )

        try "Change 1".write(to: testRepo.tempDirectory.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
        _ = try LibGit2.stash(message: "Stash 1", at: testRepo.repositoryPath, verbose: false)

        try "Change 2".write(to: testRepo.tempDirectory.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
        _ = try LibGit2.stash(message: "Stash 2", at: testRepo.repositoryPath, verbose: false)

        // 删除第一个暂存(index 0，最新的)
        try LibGit2.stashDrop(index: 0, at: testRepo.repositoryPath, verbose: false)

        // 验证剩下一个暂存
        let count = try LibGit2.getStashCount(at: testRepo.repositoryPath)
        XCTAssertEqual(count, 1)

        // 验证剩余的是原来的第二个暂存
        let stashList = try LibGit2.getStashList(at: testRepo.repositoryPath)
        XCTAssertTrue(stashList[0].message.contains("Stash 1"))
    }

    func testStashDropSpecificIndex() throws {
        // 创建三个暂存
        try testRepo.createFileAndCommit(
            fileName: "file.txt",
            content: "Original",
            message: "Initial commit"
        )

        for i in 1...3 {
            try "Change \(i)".write(to: testRepo.tempDirectory.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
            _ = try LibGit2.stash(message: "Stash \(i)", at: testRepo.repositoryPath, verbose: false)
        }

        XCTAssertEqual(try LibGit2.getStashCount(at: testRepo.repositoryPath), 3)

        // 删除中间的暂存(index 1)
        try LibGit2.stashDrop(index: 1, at: testRepo.repositoryPath, verbose: false)

        // 验证剩下2个暂存
        XCTAssertEqual(try LibGit2.getStashCount(at: testRepo.repositoryPath), 2)
    }

    // MARK: - Stash Clear Tests

    func testStashClear() throws {
        // 创建多个暂存
        try testRepo.createFileAndCommit(
            fileName: "file.txt",
            content: "Original",
            message: "Initial commit"
        )

        try "Change 1".write(to: testRepo.tempDirectory.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
        _ = try LibGit2.stash(at: testRepo.repositoryPath, verbose: false)

        try "Change 2".write(to: testRepo.tempDirectory.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
        _ = try LibGit2.stash(at: testRepo.repositoryPath, verbose: false)

        XCTAssertEqual(try LibGit2.getStashCount(at: testRepo.repositoryPath), 2)

        // 清空所有暂存
        try LibGit2.stashClear(at: testRepo.repositoryPath, verbose: false)

        // 验证暂存列表已清空
        XCTAssertFalse(try LibGit2.hasStash(at: testRepo.repositoryPath))
        XCTAssertEqual(try LibGit2.getStashCount(at: testRepo.repositoryPath), 0)
    }

    func testStashClearEmptyList() throws {
        // 没有暂存时清空
        try testRepo.createFileAndCommit(
            fileName: "file.txt",
            content: "Content",
            message: "Initial commit"
        )

        XCTAssertFalse(try LibGit2.hasStash(at: testRepo.repositoryPath))

        // 清空空列表应该成功
        try LibGit2.stashClear(at: testRepo.repositoryPath, verbose: false)

        XCTAssertFalse(try LibGit2.hasStash(at: testRepo.repositoryPath))
    }

    // MARK: - Stash Count Tests

    func testGetStashCount() throws {
        // 创建初始提交
        try testRepo.createFileAndCommit(
            fileName: "file.txt",
            content: "Content",
            message: "Initial commit"
        )

        // 最初没有暂存
        XCTAssertEqual(try LibGit2.getStashCount(at: testRepo.repositoryPath), 0)

        // 创建暂存
        try "Modified".write(to: testRepo.tempDirectory.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
        _ = try LibGit2.stash(at: testRepo.repositoryPath, verbose: false)

        let count1 = try LibGit2.getStashCount(at: testRepo.repositoryPath)
        XCTAssertEqual(count1, 1, "Should have 1 stash after first stash")

        // 再创建一个不同的暂存
        try "Different change".write(to: testRepo.tempDirectory.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
        _ = try LibGit2.stash(at: testRepo.repositoryPath, verbose: false)

        let count2 = try LibGit2.getStashCount(at: testRepo.repositoryPath)
        XCTAssertEqual(count2, count1 + 1, "Stash count should increase")
    }

    func testHasStash() throws {
        // 创建初始提交
        try testRepo.createFileAndCommit(
            fileName: "file.txt",
            content: "Content",
            message: "Initial commit"
        )

        // 最初没有暂存
        XCTAssertFalse(try LibGit2.hasStash(at: testRepo.repositoryPath))

        // 创建暂存
        try "Modified".write(to: testRepo.tempDirectory.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
        _ = try LibGit2.stash(at: testRepo.repositoryPath, verbose: false)

        XCTAssertTrue(try LibGit2.hasStash(at: testRepo.repositoryPath))

        // 删除暂存
        try LibGit2.stashDrop(at: testRepo.repositoryPath, verbose: false)

        XCTAssertFalse(try LibGit2.hasStash(at: testRepo.repositoryPath))
    }

    // MARK: - Edge Cases

    func testStashNewFile() throws {
        // 创建初始提交
        try testRepo.createFileAndCommit(
            fileName: "initial.txt",
            content: "Content",
            message: "Initial commit"
        )

        // 创建新文件
        let newFileURL = testRepo.tempDirectory.appendingPathComponent("newfile.txt")
        try "New file content".write(to: newFileURL, atomically: true, encoding: .utf8)

        // 暂存新文件
        _ = try LibGit2.stash(at: testRepo.repositoryPath, verbose: false)

        // 验证新文件已从工作区删除
        assertFileNotExists("newfile.txt", in: testRepo)

        // 验证有暂存记录
        XCTAssertTrue(try LibGit2.hasStash(at: testRepo.repositoryPath))
    }

    func testStashDeletedFile() throws {
        // 创建文件并提交
        try testRepo.createFileAndCommit(
            fileName: "toDelete.txt",
            content: "Will be deleted",
            message: "Initial commit"
        )

        // 删除文件
        let fileURL = testRepo.tempDirectory.appendingPathComponent("toDelete.txt")
        try FileManager.default.removeItem(at: fileURL)

        // 暂存删除操作
        _ = try LibGit2.stash(at: testRepo.repositoryPath, verbose: false)

        // 验证文件已恢复
        assertFileExists("toDelete.txt", in: testRepo)

        // 验证有暂存记录
        XCTAssertTrue(try LibGit2.hasStash(at: testRepo.repositoryPath))
    }
}
