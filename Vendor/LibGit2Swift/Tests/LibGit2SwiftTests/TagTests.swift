import Foundation
@testable import LibGit2Swift
import XCTest

/// Tag 相关功能的测试
final class TagTests: LibGit2SwiftTestCase {

    // MARK: - Get Tags Tests

    func testGetTagsEmptyRepo() throws {
        // 创建初始提交
        try testRepo.createFileAndCommit(
            fileName: "initial.txt",
            content: "Initial content",
            message: "Initial commit"
        )

        // 空仓库应该没有标签
        let tags = try LibGit2.getTags(at: testRepo.repositoryPath)
        XCTAssertTrue(tags.isEmpty)
    }

    func testGetTags() throws {
        // 创建提交和标签
        try testRepo.createFileAndCommit(
            fileName: "file.txt",
            content: "Content",
            message: "Initial commit"
        )

        try testRepo.createTag(tagName: "v1.0.0", message: "Version 1.0.0")
        try testRepo.createTag(tagName: "v2.0.0", message: "Version 2.0.0")

        // 获取标签列表
        let tags = try LibGit2.getTags(at: testRepo.repositoryPath)
        XCTAssertEqual(tags.count, 2)
        XCTAssertTrue(tags.contains("v1.0.0"))
        XCTAssertTrue(tags.contains("v2.0.0"))
    }

    func testGetTagsForCommit() throws {
        // 创建多个提交
        try testRepo.createFileAndCommit(
            fileName: "file1.txt",
            content: "Content 1",
            message: "Commit 1"
        )

        let hash1 = try LibGit2.getCommitList(at: testRepo.repositoryPath, limit: 1)[0].hash

        try testRepo.createFileAndCommit(
            fileName: "file2.txt",
            content: "Content 2",
            message: "Commit 2"
        )

        // 在第一个提交创建标签
        try LibGit2.createTag(named: "v1.0", message: "Version 1", at: hash1, in: testRepo.repositoryPath, verbose: false)

        // 获取第一个提交的标签
        let tagsForCommit = try LibGit2.getTags(at: testRepo.repositoryPath, for: hash1)
        XCTAssertEqual(tagsForCommit.count, 1)
        XCTAssertTrue(tagsForCommit.contains("v1.0"))
    }

    // MARK: - Create Tag Tests

    func testCreateLightweightTag() throws {
        // 创建提交
        try testRepo.createFileAndCommit(
            fileName: "file.txt",
            content: "Content",
            message: "Initial commit"
        )

        // 创建轻量标签（无消息）
        try LibGit2.createTag(named: "lightweight", message: nil, in: testRepo.repositoryPath, verbose: false)

        // 验证标签存在
        let tags = try LibGit2.getTags(at: testRepo.repositoryPath)
        XCTAssertTrue(tags.contains("lightweight"))
    }

    func testCreateAnnotatedTag() throws {
        // 创建提交
        try testRepo.createFileAndCommit(
            fileName: "file.txt",
            content: "Content",
            message: "Initial commit"
        )

        // 创建带注释的标签
        let message = "Release version 1.0"
        try LibGit2.createTag(named: "annotated", message: message, in: testRepo.repositoryPath, verbose: false)

        // 验证标签存在
        let tags = try LibGit2.getTags(at: testRepo.repositoryPath)
        XCTAssertTrue(tags.contains("annotated"))
    }

    func testCreateTagAtSpecificCommit() throws {
        // 创建多个提交
        try testRepo.createFileAndCommit(
            fileName: "file1.txt",
            content: "Content 1",
            message: "Commit 1"
        )

        let hash1 = try LibGit2.getCommitList(at: testRepo.repositoryPath, limit: 1)[0].hash

        try testRepo.createFileAndCommit(
            fileName: "file2.txt",
            content: "Content 2",
            message: "Commit 2"
        )

        // 在特定提交创建标签
        try LibGit2.createTag(named: "v0.1", at: hash1, in: testRepo.repositoryPath, verbose: false)

        // 验证标签指向正确的提交
        let tagsForCommit = try LibGit2.getTags(at: testRepo.repositoryPath, for: hash1)
        XCTAssertTrue(tagsForCommit.contains("v0.1"))
    }

    func testCreateTagAtHEAD() throws {
        // 创建提交
        try testRepo.createFileAndCommit(
            fileName: "file.txt",
            content: "Content",
            message: "Initial commit"
        )

        // 在HEAD创建标签（不指定commit hash）
        try LibGit2.createTag(named: "current", message: nil, at: nil, in: testRepo.repositoryPath, verbose: false)

        // 验证标签存在
        let tags = try LibGit2.getTags(at: testRepo.repositoryPath)
        XCTAssertTrue(tags.contains("current"))

        // 验证标签指向当前提交
        let hash = try LibGit2.getCommitList(at: testRepo.repositoryPath, limit: 1)[0].hash
        let tagsForCommit = try LibGit2.getTags(at: testRepo.repositoryPath, for: hash)
        XCTAssertTrue(tagsForCommit.contains("current"))
    }

    func testCreateDuplicateTag() throws {
        // 创建提交
        try testRepo.createFileAndCommit(
            fileName: "file.txt",
            content: "Content",
            message: "Initial commit"
        )

        // 创建标签
        try LibGit2.createTag(named: "duplicate", message: nil, in: testRepo.repositoryPath, verbose: false)

        // 再次创建同名标签应该失败
        XCTAssertThrowsError(try LibGit2.createTag(named: "duplicate", message: nil, in: testRepo.repositoryPath, verbose: false)) { error in
            XCTAssertTrue(error is LibGit2Error)
        }
    }

    // MARK: - Delete Tag Tests

    func testDeleteTag() throws {
        // 创建提交和标签
        try testRepo.createFileAndCommit(
            fileName: "file.txt",
            content: "Content",
            message: "Initial commit"
        )

        try testRepo.createTag(tagName: "toDelete", message: nil)

        // 验证标签存在
        XCTAssertTrue(try LibGit2.getTags(at: testRepo.repositoryPath).contains("toDelete"))

        // 删除标签
        try LibGit2.deleteTag(named: "toDelete", at: testRepo.repositoryPath, verbose: false)

        // 验证标签已删除
        XCTAssertFalse(try LibGit2.getTags(at: testRepo.repositoryPath).contains("toDelete"))
    }

    func testDeleteNonExistentTag() throws {
        // 创建提交
        try testRepo.createFileAndCommit(
            fileName: "file.txt",
            content: "Content",
            message: "Initial commit"
        )

        // 删除不存在的标签应该失败
        XCTAssertThrowsError(try LibGit2.deleteTag(named: "nonexistent", at: testRepo.repositoryPath, verbose: false)) { error in
            XCTAssertTrue(error is LibGit2Error)
        }
    }

    // MARK: - Get Tag Target Tests

    func testGetTagTarget() throws {
        // 创建提交
        try testRepo.createFileAndCommit(
            fileName: "file.txt",
            content: "Content",
            message: "Initial commit"
        )

        let commitHash = try LibGit2.getCommitList(at: testRepo.repositoryPath, limit: 1)[0].hash

        // 创建标签
        try LibGit2.createTag(named: "test-tag", message: nil, in: testRepo.repositoryPath, verbose: false)

        // 获取标签指向的提交
        let targetHash = try LibGit2.getTagTarget(name: "test-tag", at: testRepo.repositoryPath)
        XCTAssertEqual(targetHash, commitHash)
    }

    func testGetAnnotatedTagTarget() throws {
        // 创建提交
        try testRepo.createFileAndCommit(
            fileName: "file.txt",
            content: "Content",
            message: "Initial commit"
        )

        let commitHash = try LibGit2.getCommitList(at: testRepo.repositoryPath, limit: 1)[0].hash

        // 创建带注释的标签
        try LibGit2.createTag(named: "annotated-tag", message: "Tag message", in: testRepo.repositoryPath, verbose: false)

        // 获取标签指向的提交
        let targetHash = try LibGit2.getTagTarget(name: "annotated-tag", at: testRepo.repositoryPath)
        XCTAssertEqual(targetHash, commitHash)
    }

    func testGetTagTargetNonExistent() throws {
        // 创建提交
        try testRepo.createFileAndCommit(
            fileName: "file.txt",
            content: "Content",
            message: "Initial commit"
        )

        // 获取不存在标签的目标应该失败
        XCTAssertThrowsError(try LibGit2.getTagTarget(name: "no-tag", at: testRepo.repositoryPath)) { error in
            XCTAssertTrue(error is LibGit2Error)
        }
    }

    // MARK: - Edge Cases

    func testTagWithSpecialCharacters() throws {
        // 创建提交
        try testRepo.createFileAndCommit(
            fileName: "file.txt",
            content: "Content",
            message: "Initial commit"
        )

        // 创建包含特殊字符的标签
        try LibGit2.createTag(named: "v1.0-beta", message: "Beta release", in: testRepo.repositoryPath, verbose: false)

        let tags = try LibGit2.getTags(at: testRepo.repositoryPath)
        XCTAssertTrue(tags.contains("v1.0-beta"))
    }

    func testMultipleTagsOnSameCommit() throws {
        // 创建提交
        try testRepo.createFileAndCommit(
            fileName: "file.txt",
            content: "Content",
            message: "Initial commit"
        )

        let hash = try LibGit2.getCommitList(at: testRepo.repositoryPath, limit: 1)[0].hash

        // 创建多个标签指向同一提交
        try LibGit2.createTag(named: "v1.0", message: nil, in: testRepo.repositoryPath, verbose: false)
        try LibGit2.createTag(named: "release-1", message: nil, in: testRepo.repositoryPath, verbose: false)

        // 验证所有标签都指向该提交
        let tagsForCommit = try LibGit2.getTags(at: testRepo.repositoryPath, for: hash)
        XCTAssertEqual(tagsForCommit.count, 2)
        XCTAssertTrue(tagsForCommit.contains("v1.0"))
        XCTAssertTrue(tagsForCommit.contains("release-1"))
    }

    func testCreateTagInEmptyRepository() throws {
        // 空仓库创建标签应该失败
        XCTAssertThrowsError(try LibGit2.createTag(named: "fail", message: nil, in: testRepo.repositoryPath, verbose: false)) { error in
            XCTAssertTrue(error is LibGit2Error)
        }
    }
}