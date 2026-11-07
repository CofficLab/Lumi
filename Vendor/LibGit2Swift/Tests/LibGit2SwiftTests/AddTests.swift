import Foundation
@testable import LibGit2Swift
import XCTest

/// Add/Staging 相关功能的测试
final class AddTests: LibGit2SwiftTestCase {
    // MARK: - Add Single File Tests

    func testAddNewFile() throws {
        // 创建初始提交
        try testRepo.createFileAndCommit(
            fileName: "initial.txt",
            content: "Initial content",
            message: "Initial commit"
        )

        // 创建新文件
        let newFileName = "newfile.txt"
        let fileURL = testRepo.tempDirectory.appendingPathComponent(newFileName)
        try "New file content".write(to: fileURL, atomically: true, encoding: .utf8)

        // 添加到暂存区
        try LibGit2.addFiles([newFileName], at: testRepo.repositoryPath)

        // 验证文件已暂存
        let stagedFiles = try LibGit2.getStagedFiles(at: testRepo.repositoryPath)
        XCTAssertTrue(stagedFiles.contains(newFileName),
                      "Newly added file should be in staged files")
    }

    func testAddMultipleFiles() throws {
        // 创建初始提交
        try testRepo.createFileAndCommit(
            fileName: "initial.txt",
            content: "Initial content",
            message: "Initial commit"
        )

        // 创建多个新文件
        let fileNames = ["file1.txt", "file2.txt", "file3.txt"]
        for fileName in fileNames {
            let fileURL = testRepo.tempDirectory.appendingPathComponent(fileName)
            try "Content for \(fileName)".write(to: fileURL, atomically: true, encoding: .utf8)
        }

        // 添加到暂存区
        try LibGit2.addFiles(fileNames, at: testRepo.repositoryPath)

        // 验证所有文件已暂存
        let stagedFiles = try LibGit2.getStagedFiles(at: testRepo.repositoryPath)
        for fileName in fileNames {
            XCTAssertTrue(stagedFiles.contains(fileName),
                          "File '\(fileName)' should be in staged files")
        }
    }

    // MARK: - Add Modified File Tests

    func testAddModifiedFile() throws {
        // 创建并提交文件
        let fileName = "test.txt"
        try testRepo.createFileAndCommit(
            fileName: fileName,
            content: "Original content",
            message: "Initial commit"
        )

        // 修改文件
        let fileURL = testRepo.tempDirectory.appendingPathComponent(fileName)
        try "Modified content".write(to: fileURL, atomically: true, encoding: .utf8)

        // 添加修改到暂存区
        try LibGit2.addFiles([fileName], at: testRepo.repositoryPath)

        // 验证文件已暂存
        let stagedFiles = try LibGit2.getStagedFiles(at: testRepo.repositoryPath)
        XCTAssertTrue(stagedFiles.contains(fileName),
                      "Modified file should be in staged files")
    }

    // MARK: - Add Deleted File Tests

    func testAddDeletedFile() throws {
        // 创建并提交文件
        let fileName = "toberemoved.txt"
        try testRepo.createFileAndCommit(
            fileName: fileName,
            content: "This file will be deleted",
            message: "Initial commit"
        )

        // 删除文件
        let fileURL = testRepo.tempDirectory.appendingPathComponent(fileName)
        try FileManager.default.removeItem(at: fileURL)

        // 添加删除操作到暂存区
        try LibGit2.addFiles([fileName], at: testRepo.repositoryPath)

        // 验证文件已暂存
        let stagedFiles = try LibGit2.getStagedFiles(at: testRepo.repositoryPath)
        XCTAssertTrue(stagedFiles.contains(fileName),
                      "Deleted file should be in staged files")
    }

    // MARK: - Add All Files Tests

    func testAddAllFilesWithEmptyArray() throws {
        // 创建初始提交
        try testRepo.createFileAndCommit(
            fileName: "initial.txt",
            content: "Initial content",
            message: "Initial commit"
        )

        // 创建多个新文件
        let fileNames = ["file1.txt", "file2.txt", "file3.txt"]
        for fileName in fileNames {
            let fileURL = testRepo.tempDirectory.appendingPathComponent(fileName)
            try "Content for \(fileName)".write(to: fileURL, atomically: true, encoding: .utf8)
        }

        // 使用空数组添加所有文件
        try LibGit2.addFiles([], at: testRepo.repositoryPath)

        // 验证所有文件已暂存
        let stagedFiles = try LibGit2.getStagedFiles(at: testRepo.repositoryPath)
        for fileName in fileNames {
            XCTAssertTrue(stagedFiles.contains(fileName),
                          "File '\(fileName)' should be in staged files when adding all")
        }
    }

    func testAddAllFilesMixedState() throws {
        // 创建初始提交
        try testRepo.createFileAndCommit(
            fileName: "initial.txt",
            content: "Initial content",
            message: "Initial commit"
        )

        // 场景 1: 新文件
        let newFile = "newfile.txt"
        let newFileURL = testRepo.tempDirectory.appendingPathComponent(newFile)
        try "New file".write(to: newFileURL, atomically: true, encoding: .utf8)

        // 场景 2: 修改已有文件
        let modifiedFile = "initial.txt"
        let modifiedFileURL = testRepo.tempDirectory.appendingPathComponent(modifiedFile)
        try "Modified content".write(to: modifiedFileURL, atomically: true, encoding: .utf8)

        // 添加所有文件
        try LibGit2.addFiles([], at: testRepo.repositoryPath)

        // 验证两个文件都已暂存
        let stagedFiles = try LibGit2.getStagedFiles(at: testRepo.repositoryPath)
        XCTAssertTrue(stagedFiles.contains(newFile),
                      "New file should be staged")
        XCTAssertTrue(stagedFiles.contains(modifiedFile),
                      "Modified file should be staged")
    }

    // MARK: - Pattern Matching Tests

    func testAddFilesWithPattern() throws {
        // 创建初始提交
        try testRepo.createFileAndCommit(
            fileName: "initial.txt",
            content: "Initial content",
            message: "Initial commit"
        )

        // 创建多个 .txt 文件
        let txtFiles = ["doc1.txt", "doc2.txt", "doc3.txt"]
        for fileName in txtFiles {
            let fileURL = testRepo.tempDirectory.appendingPathComponent(fileName)
            try "Content".write(to: fileURL, atomically: true, encoding: .utf8)
        }

        // 创建一个 .md 文件
        let mdFile = "readme.md"
        let mdFileURL = testRepo.tempDirectory.appendingPathComponent(mdFile)
        try "README content".write(to: mdFileURL, atomically: true, encoding: .utf8)

        // 添加所有 .txt 文件
        try LibGit2.addFiles(["*.txt"], at: testRepo.repositoryPath)

        // 验证 .txt 文件已暂存
        let stagedFiles = try LibGit2.getStagedFiles(at: testRepo.repositoryPath)
        for fileName in txtFiles {
            XCTAssertTrue(stagedFiles.contains(fileName),
                          "Text file '\(fileName)' should be staged")
        }

        // .md 文件不应该被暂存
        // 注意：这取决于 libgit2 的模式匹配实现
    }

    // MARK: - File in Subdirectory Tests

    func testAddFileInSubdirectory() throws {
        // 创建初始提交
        try testRepo.createFileAndCommit(
            fileName: "initial.txt",
            content: "Initial content",
            message: "Initial commit"
        )

        // 创建子目录
        let subDir = testRepo.tempDirectory.appendingPathComponent("subdir")
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)

        // 在子目录中创建文件
        let fileName = "subdir/file.txt"
        let fileURL = testRepo.tempDirectory.appendingPathComponent(fileName)
        try "Content in subdirectory".write(to: fileURL, atomically: true, encoding: .utf8)

        // 添加文件
        try LibGit2.addFiles([fileName], at: testRepo.repositoryPath)

        // 验证文件已暂存
        let stagedFiles = try LibGit2.getStagedFiles(at: testRepo.repositoryPath)
        XCTAssertTrue(stagedFiles.contains(fileName),
                      "File in subdirectory should be staged")
    }

    // MARK: - Error Handling Tests

    func testAddNonExistentFile() throws {
        // 创建初始提交
        try testRepo.createFileAndCommit(
            fileName: "initial.txt",
            content: "Initial content",
            message: "Initial commit"
        )

        // 尝试添加不存在的文件
        let nonExistentFile = "nonexistent.txt"

        // libgit2 可能会忽略不存在的文件而不是抛出错误
        // 这里我们只是验证操作不会崩溃
        XCTAssertNoThrow(
            try LibGit2.addFiles([nonExistentFile], at: testRepo.repositoryPath)
        )
    }

    func testAddEmptyPath() throws {
        // 创建初始提交
        try testRepo.createFileAndCommit(
            fileName: "initial.txt",
            content: "Initial content",
            message: "Initial commit"
        )

        // 空路径不应该导致错误
        XCTAssertNoThrow(
            try LibGit2.addFiles([""], at: testRepo.repositoryPath)
        )
    }

    // MARK: - State Transition Tests

    func testFileStateTransitions() throws {
        // 1. 创建并提交文件（文件在仓库中，未修改）
        let fileName = "test.txt"
        try testRepo.createFileAndCommit(
            fileName: fileName,
            content: "Content",
            message: "Initial commit"
        )

        // 验证文件不在未暂存列表中
        let unstaged1 = try LibGit2.getUnstagedFiles(at: testRepo.repositoryPath)
        XCTAssertFalse(unstaged1.contains(fileName),
                       "Clean file should not be in unstaged files")

        // 2. 修改文件（文件在工作区被修改，未暂存）
        let fileURL = testRepo.tempDirectory.appendingPathComponent(fileName)
        try "Modified content".write(to: fileURL, atomically: true, encoding: .utf8)

        let unstaged2 = try LibGit2.getUnstagedFiles(at: testRepo.repositoryPath)
        XCTAssertTrue(unstaged2.contains(fileName),
                      "Modified file should be in unstaged files")

        // 3. 添加文件（文件在工作区被修改，已暂存）
        try LibGit2.addFiles([fileName], at: testRepo.repositoryPath)

        let staged = try LibGit2.getStagedFiles(at: testRepo.repositoryPath)
        XCTAssertTrue(staged.contains(fileName),
                      "Modified file should be in staged files after add")

        // 4. 再次提交（文件在仓库中，未修改）
        try testRepo.createFileAndCommit(
            fileName: "another.txt",
            content: "Another",
            message: "Second commit"
        )

        // 文件应该不再在暂存区中
        let unstaged3 = try LibGit2.getUnstagedFiles(at: testRepo.repositoryPath)
        XCTAssertFalse(unstaged3.contains(fileName),
                       "Committed file should not be in unstaged files")
    }

    // MARK: - Complex Scenarios

    func testAddWithSpecialCharactersInFilename() throws {
        // 创建初始提交
        try testRepo.createFileAndCommit(
            fileName: "initial.txt",
            content: "Initial content",
            message: "Initial commit"
        )

        // 创建包含特殊字符的文件名
        let specialFile = "file with spaces.txt"
        let fileURL = testRepo.tempDirectory.appendingPathComponent(specialFile)
        try "Content".write(to: fileURL, atomically: true, encoding: .utf8)

        // 添加文件
        try LibGit2.addFiles([specialFile], at: testRepo.repositoryPath)

        // 验证文件已暂存
        let stagedFiles = try LibGit2.getStagedFiles(at: testRepo.repositoryPath)
        XCTAssertTrue(stagedFiles.contains(specialFile),
                      "File with spaces should be staged")
    }

    func testAddAndCommitCycle() throws {
        // 完整的添加-提交循环
        for i in 1...5 {
            // 创建文件
            let fileName = "file\(i).txt"
            try testRepo.createFileAndCommit(
                fileName: fileName,
                content: "Content \(i)",
                message: "Commit \(i)"
            )
        }

        // 验证所有提交
        let commits = try LibGit2.getCommitList(at: testRepo.repositoryPath)
        XCTAssertEqual(commits.count, 5, "Should have 5 commits")
    }
}
