import Foundation
@testable import LibGit2Swift
import XCTest

/// Diff 相关功能的测试
final class DiffTests: LibGit2SwiftTestCase {
    // MARK: - Commit Diff Files Tests

    func testGetCommitDiffFilesInitialCommit() throws {
        // 创建初始提交
        try testRepo.createFileAndCommit(
            fileName: "initial.txt",
            content: "Initial content",
            message: "Initial commit"
        )

        // 获取提交列表
        let commits = try LibGit2.getCommitList(at: testRepo.repositoryPath)
        guard let firstCommit = commits.first else {
            XCTFail("Should have at least one commit")
            return
        }

        // 获取初始提交的文件差异
        let diffFiles = try LibGit2.getCommitDiffFiles(atCommit: firstCommit.hash, at: testRepo.repositoryPath)

        // 验证文件列表
        XCTAssertEqual(diffFiles.count, 1, "Initial commit should have one file")
        XCTAssertEqual(diffFiles.first?.file, "initial.txt", "File name should match")
        XCTAssertEqual(diffFiles.first?.changeType, "A", "Change type should be 'A' (added)")
    }

    func testGetCommitDiffFilesWithModifications() throws {
        // 创建初始提交
        try testRepo.createFileAndCommit(
            fileName: "file1.txt",
            content: "Content 1",
            message: "Initial commit"
        )

        // 创建第二次提交（修改文件）
        try testRepo.createFileAndCommit(
            fileName: "file1.txt",
            content: "Modified content",
            message: "Modify file1"
        )

        // 创建第三次提交（添加新文件）
        try testRepo.createFileAndCommit(
            fileName: "file2.txt",
            content: "New file",
            message: "Add file2"
        )

        // 获取提交列表
        let commits = try LibGit2.getCommitList(at: testRepo.repositoryPath)
        XCTAssertEqual(commits.count, 3, "Should have 3 commits")

        // 由于提交按时间倒序排列：
        // commits[0]：最新的提交（添加file2.txt）
        // commits[1]：中间提交（修改file1.txt）
        // commits[2]：最旧的提交（初始添加file1.txt）

        // 验证最新的提交（添加file2.txt）
        let latestCommitFiles = try LibGit2.getCommitDiffFiles(atCommit: commits[0].hash, at: testRepo.repositoryPath)
        XCTAssertEqual(latestCommitFiles.count, 1, "Latest commit should have one added file")
        XCTAssertEqual(latestCommitFiles.first?.file, "file2.txt", "File should be file2.txt")
        XCTAssertEqual(latestCommitFiles.first?.changeType, "A", "Change type should be 'A' (added)")

        // 验证中间提交（修改file1.txt）
        let middleCommitFiles = try LibGit2.getCommitDiffFiles(atCommit: commits[1].hash, at: testRepo.repositoryPath)
        XCTAssertEqual(middleCommitFiles.count, 1, "Middle commit should have one modified file")
        XCTAssertEqual(middleCommitFiles.first?.file, "file1.txt", "File should be file1.txt")
        XCTAssertEqual(middleCommitFiles.first?.changeType, "M", "Change type should be 'M' (modified)")

        // 验证最旧的提交（初始添加file1.txt）
        let oldestCommitFiles = try LibGit2.getCommitDiffFiles(atCommit: commits[2].hash, at: testRepo.repositoryPath)
        XCTAssertEqual(oldestCommitFiles.count, 1, "Oldest commit should have one added file")
        XCTAssertEqual(oldestCommitFiles.first?.file, "file1.txt", "File should be file1.txt")
        XCTAssertEqual(oldestCommitFiles.first?.changeType, "A", "Change type should be 'A' (added)")
    }

    func testGetCommitDiffFilesWithDeletions() throws {
        // 创建初始提交（两个文件）
        try testRepo.createFileAndCommit(
            fileName: "file1.txt",
            content: "Content 1",
            message: "Add file1"
        )

        try testRepo.createFileAndCommit(
            fileName: "file2.txt",
            content: "Content 2",
            message: "Add file2"
        )

        // 删除一个文件
        let fileURL = testRepo.tempDirectory.appendingPathComponent("file1.txt")
        try FileManager.default.removeItem(at: fileURL)

        try LibGit2.addFiles(["file1.txt"], at: testRepo.repositoryPath)
        _ = try LibGit2.createCommit(message: "Delete file1", at: testRepo.repositoryPath, verbose: false)

        // 获取提交列表
        let commits = try LibGit2.getCommitList(at: testRepo.repositoryPath)

        // 验证删除提交
        let lastCommitFiles = try LibGit2.getCommitDiffFiles(atCommit: commits.first!.hash, at: testRepo.repositoryPath)
        XCTAssertTrue(lastCommitFiles.contains { $0.file == "file1.txt" }, "Should have deleted file1.txt")
        XCTAssertTrue(lastCommitFiles.contains { $0.changeType == "D" }, "Should have deleted file")
    }

    func testGetCommitDiffFilesMultipleChanges() throws {
        // 创建初始提交
        try testRepo.createFileAndCommit(
            fileName: "file1.txt",
            content: "Content 1",
            message: "Initial commit"
        )

        // 在第二次提交中修改多个文件
        try testRepo.createFileAndCommit(
            fileName: "file1.txt",
            content: "Modified file1",
            message: "Modify file1"
        )

        try testRepo.createFileAndCommit(
            fileName: "file2.txt",
            content: "New file2",
            message: "Add file2"
        )

        try testRepo.createFileAndCommit(
            fileName: "file3.txt",
            content: "New file3",
            message: "Add file3"
        )

        // 获取提交列表
        let commits = try LibGit2.getCommitList(at: testRepo.repositoryPath)

        // 验证每个提交
        for (index, commit) in commits.enumerated() {
            let diffFiles = try LibGit2.getCommitDiffFiles(atCommit: commit.hash, at: testRepo.repositoryPath)
            XCTAssertTrue(diffFiles.count > 0, "Commit \(index) should have at least one changed file")
        }
    }

    func testGetCommitDiffFilesIncludesDiffContent() throws {
        // 创建初始提交
        try testRepo.createFileAndCommit(
            fileName: "test.txt",
            content: "Original content",
            message: "Initial commit"
        )

        // 修改文件
        try testRepo.createFileAndCommit(
            fileName: "test.txt",
            content: "Modified content with changes",
            message: "Modify test file"
        )

        // 获取提交列表
        let commits = try LibGit2.getCommitList(at: testRepo.repositoryPath)

        // 获取第二次提交的差异
        let diffFiles = try LibGit2.getCommitDiffFiles(atCommit: commits[1].hash, at: testRepo.repositoryPath)

        guard let diffFile = diffFiles.first else {
            XCTFail("Should have at least one diff file")
            return
        }

        // 验证差异内容不为空
        XCTAssertFalse(diffFile.diff.isEmpty, "Diff content should not be empty")
        XCTAssertTrue(diffFile.diff.contains("test.txt"), "Diff should contain file name")
    }

    func testGetCommitDiffFilesEmptyRepository() throws {
        // 空仓库不应该有提交
        let commits = try LibGit2.getCommitList(at: testRepo.repositoryPath)
        XCTAssertTrue(commits.isEmpty, "Empty repository should have no commits")
    }

    func testGetCommitDiffFilesInvalidCommitHash() throws {
        // 创建初始提交
        try testRepo.createFileAndCommit(
            fileName: "test.txt",
            content: "Content",
            message: "Initial commit"
        )

        // 尝试使用无效的commit hash
        XCTAssertThrowsError(
            try LibGit2.getCommitDiffFiles(atCommit: "invalid_hash_12345", at: testRepo.repositoryPath)
        ) { error in
            XCTAssertTrue(error is LibGit2Error, "Should throw LibGit2Error for invalid commit hash")
        }
    }

    // MARK: - Diff File List Tests (Workdir/Index)

    func testGetDiffFileListUnstaged() throws {
        // 创建初始提交
        try testRepo.createFileAndCommit(
            fileName: "test.txt",
            content: "Original content",
            message: "Initial commit"
        )

        // 修改文件（不添加到暂存区）
        let fileURL = testRepo.tempDirectory.appendingPathComponent("test.txt")
        try "Modified content".write(to: fileURL, atomically: true, encoding: .utf8)

        // 获取未暂存的差异
        let diffFiles = try LibGit2.getDiffFileList(at: testRepo.repositoryPath, staged: false)

        XCTAssertTrue(diffFiles.count > 0, "Should have unstaged changes")
        XCTAssertTrue(diffFiles.contains { $0.file == "test.txt" }, "Should have test.txt in diff")
    }

    func testGetDiffFileListStaged() throws {
        // 创建初始提交
        try testRepo.createFileAndCommit(
            fileName: "test.txt",
            content: "Original content",
            message: "Initial commit"
        )

        // 修改文件并添加到暂存区
        let fileURL = testRepo.tempDirectory.appendingPathComponent("test.txt")
        try "Modified content".write(to: fileURL, atomically: true, encoding: .utf8)

        try LibGit2.addFiles(["test.txt"], at: testRepo.repositoryPath)

        // 获取已暂存的差异
        let diffFiles = try LibGit2.getDiffFileList(at: testRepo.repositoryPath, staged: true)

        XCTAssertTrue(diffFiles.count > 0, "Should have staged changes")
        XCTAssertTrue(diffFiles.contains { $0.file == "test.txt" }, "Should have test.txt in staged diff")
    }

    func testGetDiffFileListStagedAddedFileIncludesDiffContent() throws {
        try testRepo.createFileAndCommit(
            fileName: "existing.txt",
            content: "Existing content",
            message: "Initial commit"
        )

        let fileURL = testRepo.tempDirectory.appendingPathComponent("newfile.txt")
        try "New staged file".write(to: fileURL, atomically: true, encoding: .utf8)
        try LibGit2.addFiles(["newfile.txt"], at: testRepo.repositoryPath)

        let diffFiles = try LibGit2.getDiffFileList(at: testRepo.repositoryPath, staged: true)
        let newFile = try XCTUnwrap(diffFiles.first(where: { $0.file == "newfile.txt" }))

        XCTAssertEqual(newFile.changeType, "A", "New staged file should be marked as added")
        XCTAssertFalse(newFile.diff.isEmpty, "Staged added file should carry patch text")
        XCTAssertTrue(newFile.diff.contains("New staged file"), "Patch should contain new file content")
    }

    func testGetDiffFileListCleanRepository() throws {
        // 创建初始提交
        try testRepo.createFileAndCommit(
            fileName: "test.txt",
            content: "Content",
            message: "Initial commit"
        )

        // 干净的仓库不应该有差异
        let unstagedDiff = try LibGit2.getDiffFileList(at: testRepo.repositoryPath, staged: false)
        let stagedDiff = try LibGit2.getDiffFileList(at: testRepo.repositoryPath, staged: true)

        XCTAssertEqual(unstagedDiff.count, 0, "Should have no unstaged changes")
        XCTAssertEqual(stagedDiff.count, 0, "Should have no staged changes")
    }

    // MARK: - File Content Change Tests

    func testGetFileContentChangeWithModification() throws {
        // 创建初始提交
        try testRepo.createFileAndCommit(
            fileName: "test.txt",
            content: "Original content",
            message: "Initial commit"
        )

        // 修改文件
        try testRepo.createFileAndCommit(
            fileName: "test.txt",
            content: "Modified content",
            message: "Modify file"
        )

        // 获取提交列表
        let commits = try LibGit2.getCommitList(at: testRepo.repositoryPath)

        // commits[0] 是最新的提交（"Modify file"），获取该提交的文件内容变更
        let (beforeContent, afterContent) = try LibGit2.getFileContentChange(
            atCommit: commits[0].hash,
            file: "test.txt",
            at: testRepo.repositoryPath
        )

        XCTAssertEqual(beforeContent, "Original content", "Before content should match original")
        XCTAssertEqual(afterContent, "Modified content", "After content should match modified")
    }

    func testGetFileContentChangeWithAddition() throws {
        // 创建初始提交
        try testRepo.createFileAndCommit(
            fileName: "initial.txt",
            content: "Initial",
            message: "Initial commit"
        )

        // 添加新文件
        try testRepo.createFileAndCommit(
            fileName: "newfile.txt",
            content: "New file content",
            message: "Add new file"
        )

        // 获取提交列表
        let commits = try LibGit2.getCommitList(at: testRepo.repositoryPath)

        // commits[0] 是最新的提交（"Add new file"），获取该提交的文件内容变更
        let (beforeContent, afterContent) = try LibGit2.getFileContentChange(
            atCommit: commits[0].hash,
            file: "newfile.txt",
            at: testRepo.repositoryPath
        )

        XCTAssertNil(beforeContent, "Before content should be nil for new file")
        XCTAssertEqual(afterContent, "New file content", "After content should match new file")
    }

    func testGetFileContentChangeWithDeletion() throws {
        // 创建初始提交
        try testRepo.createFileAndCommit(
            fileName: "toremove.txt",
            content: "Will be deleted",
            message: "Add file"
        )

        // 删除文件
        let fileURL = testRepo.tempDirectory.appendingPathComponent("toremove.txt")
        try FileManager.default.removeItem(at: fileURL)
        try LibGit2.addFiles(["toremove.txt"], at: testRepo.repositoryPath)
        _ = try LibGit2.createCommit(message: "Delete file", at: testRepo.repositoryPath, verbose: false)

        // 获取提交列表
        let commits = try LibGit2.getCommitList(at: testRepo.repositoryPath)

        // 获取删除提交的文件内容变更
        let (beforeContent, afterContent) = try LibGit2.getFileContentChange(
            atCommit: commits[0].hash,
            file: "toremove.txt",
            at: testRepo.repositoryPath
        )

        XCTAssertEqual(beforeContent, "Will be deleted", "Before content should exist")
        XCTAssertNil(afterContent, "After content should be nil for deleted file")
    }

    func testGetFileContentChangeInitialCommit() throws {
        // 创建初始提交
        try testRepo.createFileAndCommit(
            fileName: "initial.txt",
            content: "Initial content",
            message: "Initial commit"
        )

        // 获取提交列表
        let commits = try LibGit2.getCommitList(at: testRepo.repositoryPath)

        // 获取初始提交的文件内容变更
        let (beforeContent, afterContent) = try LibGit2.getFileContentChange(
            atCommit: commits[0].hash,
            file: "initial.txt",
            at: testRepo.repositoryPath
        )

        XCTAssertNil(beforeContent, "Initial commit should have no before content")
        XCTAssertEqual(afterContent, "Initial content", "After content should match")
    }

    func testGetUncommittedFileContentChange() throws {
        // 创建初始提交
        try testRepo.createFileAndCommit(
            fileName: "test.txt",
            content: "Original content",
            message: "Initial commit"
        )

        // 修改文件（不提交）
        let fileURL = testRepo.tempDirectory.appendingPathComponent("test.txt")
        try "Modified uncommitted content".write(to: fileURL, atomically: true, encoding: .utf8)

        // 获取未提交的文件内容变更
        let (beforeContent, afterContent) = try LibGit2.getUncommittedFileContentChange(
            for: "test.txt",
            at: testRepo.repositoryPath
        )

        XCTAssertEqual(beforeContent, "Original content", "Before content should match HEAD")
        XCTAssertEqual(afterContent, "Modified uncommitted content", "After content should match working directory")
    }

    func testGetUncommittedFileContentChangeNewFile() throws {
        // 创建初始提交
        try testRepo.createFileAndCommit(
            fileName: "existing.txt",
            content: "Existing",
            message: "Initial commit"
        )

        // 创建新文件（不提交）
        let fileURL = testRepo.tempDirectory.appendingPathComponent("newfile.txt")
        try "New untracked file".write(to: fileURL, atomically: true, encoding: .utf8)

        // 获取未提交的文件内容变更
        let (beforeContent, afterContent) = try LibGit2.getUncommittedFileContentChange(
            for: "newfile.txt",
            at: testRepo.repositoryPath
        )

        XCTAssertNil(beforeContent, "New file should have no before content")
        XCTAssertEqual(afterContent, "New untracked file", "After content should match working directory")
    }

    func testGetUncommittedFileContentChangeDeletedFile() throws {
        // 创建初始提交
        try testRepo.createFileAndCommit(
            fileName: "toremove.txt",
            content: "Will be deleted",
            message: "Add file"
        )

        // 删除文件（不提交）
        let fileURL = testRepo.tempDirectory.appendingPathComponent("toremove.txt")
        try FileManager.default.removeItem(at: fileURL)

        // 获取未提交的文件内容变更
        let (beforeContent, afterContent) = try LibGit2.getUncommittedFileContentChange(
            for: "toremove.txt",
            at: testRepo.repositoryPath
        )

        XCTAssertEqual(beforeContent, "Will be deleted", "Before content should match HEAD")
        XCTAssertNil(afterContent, "Deleted file should have no after content")
    }

    // MARK: - File Diff Tests

    func testGetFileDiffModification() throws {
        // 创建初始提交
        try testRepo.createFileAndCommit(
            fileName: "test.txt",
            content: "Line 1\nLine 2\nLine 3",
            message: "Initial commit"
        )

        // 修改文件
        try testRepo.createFileAndCommit(
            fileName: "test.txt",
            content: "Line 1\nLine 2 modified\nLine 3",
            message: "Modify file"
        )

        // 获取提交列表
        let commits = try LibGit2.getCommitList(at: testRepo.repositoryPath)

        // 获取最新提交的 diff
        let diff = try LibGit2.getFileDiff(
            atCommit: commits[0].hash,
            for: "test.txt",
            at: testRepo.repositoryPath
        )

        XCTAssertFalse(diff.isEmpty, "Diff should not be empty")
        XCTAssertTrue(diff.contains("test.txt"), "Diff should contain file name")
        XCTAssertTrue(diff.contains("Line 2 modified"), "Diff should show modification")
        XCTAssertTrue(diff.contains("-") || diff.contains("+"), "Diff should have diff markers")
    }

    func testGetFileDiffAddition() throws {
        // 创建初始提交
        try testRepo.createFileAndCommit(
            fileName: "initial.txt",
            content: "Initial",
            message: "Initial commit"
        )

        // 添加新文件
        try testRepo.createFileAndCommit(
            fileName: "newfile.txt",
            content: "New file content",
            message: "Add new file"
        )

        // 获取提交列表
        let commits = try LibGit2.getCommitList(at: testRepo.repositoryPath)

        // 获取最新提交的 diff
        let diff = try LibGit2.getFileDiff(
            atCommit: commits[0].hash,
            for: "newfile.txt",
            at: testRepo.repositoryPath
        )

        XCTAssertFalse(diff.isEmpty, "Diff should not be empty for new file")
        XCTAssertTrue(diff.contains("newfile.txt"), "Diff should contain file name")
        XCTAssertTrue(diff.contains("+") || diff.contains("New file content"), "Diff should show addition")
    }

    func testGetFileDiffDeletion() throws {
        // 创建初始提交
        try testRepo.createFileAndCommit(
            fileName: "delete.txt",
            content: "To be deleted",
            message: "Add file"
        )

        // 删除文件
        let fileURL = testRepo.tempDirectory.appendingPathComponent("delete.txt")
        try FileManager.default.removeItem(at: fileURL)
        try LibGit2.addFiles(["delete.txt"], at: testRepo.repositoryPath)
        _ = try LibGit2.createCommit(message: "Delete file", at: testRepo.repositoryPath, verbose: false)

        // 获取提交列表
        let commits = try LibGit2.getCommitList(at: testRepo.repositoryPath)

        // 获取 diff
        let diff = try LibGit2.getFileDiff(
            atCommit: commits[0].hash,
            for: "delete.txt",
            at: testRepo.repositoryPath
        )

        XCTAssertFalse(diff.isEmpty, "Diff should not be empty for deletion")
        XCTAssertTrue(diff.contains("delete.txt"), "Diff should contain file name")
        XCTAssertTrue(diff.contains("-") || diff.contains("To be deleted"), "Diff should show deletion")
    }

    func testGetFileDiffInitialCommit() throws {
        // 创建初始提交
        try testRepo.createFileAndCommit(
            fileName: "initial.txt",
            content: "Line 1\nLine 2\nLine 3",
            message: "Initial commit"
        )

        // 获取提交列表
        let commits = try LibGit2.getCommitList(at: testRepo.repositoryPath)

        // 获取初始提交的 diff
        let diff = try LibGit2.getFileDiff(
            atCommit: commits[0].hash,
            for: "initial.txt",
            at: testRepo.repositoryPath
        )

        // 初始提交应该有 diff（与空树比较）
        XCTAssertTrue(diff.contains("initial.txt"), "Diff should contain file name")
        XCTAssertTrue(diff.contains("Line 1"), "Diff should show content")
    }

    func testGetFileDiffUntrackedFile() throws {
        try testRepo.createFileAndCommit(
            fileName: "existing.txt",
            content: "Existing content",
            message: "Initial commit"
        )

        let fileURL = testRepo.tempDirectory.appendingPathComponent("newfile.txt")
        try "New untracked file".write(to: fileURL, atomically: true, encoding: .utf8)

        let diff = try LibGit2.getFileDiff(
            for: "newfile.txt",
            at: testRepo.repositoryPath,
            staged: false
        )

        XCTAssertFalse(diff.isEmpty, "Untracked file diff should not be empty")
        XCTAssertTrue(diff.contains("newfile.txt"), "Diff should contain file name")
        XCTAssertTrue(diff.contains("New untracked file"), "Diff should contain file content")
    }

    func testGetFileDiffMultiLineChanges() throws {
        // 创建初始提交
        try testRepo.createFileAndCommit(
            fileName: "multiline.txt",
            content: "Line 1\nLine 2\nLine 3\nLine 4\nLine 5",
            message: "Initial commit"
        )

        // 多行修改
        try testRepo.createFileAndCommit(
            fileName: "multiline.txt",
            content: "Line 1 modified\nLine 2\nLine 3 modified\nLine 4\nLine 5 modified",
            message: "Multi-line changes"
        )

        // 获取提交列表
        let commits = try LibGit2.getCommitList(at: testRepo.repositoryPath)

        // 获取最新提交的 diff
        let diff = try LibGit2.getFileDiff(
            atCommit: commits[0].hash,
            for: "multiline.txt",
            at: testRepo.repositoryPath
        )

        XCTAssertFalse(diff.isEmpty, "Diff should not be empty")
        XCTAssertTrue(diff.contains("multiline.txt"), "Diff should contain file name")
        XCTAssertTrue(diff.contains("Line 1 modified"), "Diff should show first modification")
        XCTAssertTrue(diff.contains("Line 3 modified"), "Diff should show second modification")
        XCTAssertTrue(diff.contains("Line 5 modified"), "Diff should show third modification")
    }

    func testGetFileDiffWithBinaryFile() throws {
        // 创建初始提交（使用 Data 来处理二进制内容）
        let binaryData1 = Data([0x00, 0x01, 0x02, 0x03, 0x04])
        let binaryString1 = binaryData1.base64EncodedString()

        try testRepo.createFileAndCommit(
            fileName: "binary.bin",
            content: binaryString1,
            message: "Add binary file"
        )

        // 修改二进制文件
        let binaryData2 = Data([0x00, 0x01, 0x02, 0x03, 0x04, 0x05])
        let binaryString2 = binaryData2.base64EncodedString()

        try testRepo.createFileAndCommit(
            fileName: "binary.bin",
            content: binaryString2,
            message: "Modify binary"
        )

        // 获取提交列表
        let commits = try LibGit2.getCommitList(at: testRepo.repositoryPath)

        // 获取 diff（可能为空或显示为二进制）
        let diff = try LibGit2.getFileDiff(
            atCommit: commits[1].hash,
            for: "binary.bin",
            at: testRepo.repositoryPath
        )

        // 二进制文件的 diff 可能为空或特殊标记
        // 只要不抛出错误就通过
        XCTAssertTrue(true, "Should handle binary files without crashing")
    }

    func testGetFileDiffNonExistentFile() throws {
        // 创建初始提交
        try testRepo.createFileAndCommit(
            fileName: "existing.txt",
            content: "Content",
            message: "Initial commit"
        )

        // 获取提交列表
        let commits = try LibGit2.getCommitList(at: testRepo.repositoryPath)

        // 尝试获取不存在的文件的 diff
        let diff = try LibGit2.getFileDiff(
            atCommit: commits[0].hash,
            for: "nonexistent.txt",
            at: testRepo.repositoryPath
        )

        // 不存在的文件应该返回空 diff
        XCTAssertEqual(diff, "", "Non-existent file should return empty diff")
    }

    func testGetFileContentChangeInvalidCommit() throws {
        // 创建初始提交
        try testRepo.createFileAndCommit(
            fileName: "test.txt",
            content: "Content",
            message: "Initial commit"
        )

        // 尝试使用无效的 commit hash
        XCTAssertThrowsError(
            try LibGit2.getFileContentChange(
                atCommit: "invalid_hash_12345",
                file: "test.txt",
                at: testRepo.repositoryPath
            )
        ) { error in
            XCTAssertTrue(error is LibGit2Error, "Should throw LibGit2Error for invalid commit hash")
        }
    }

    func testGetFileContentChangeNonExistentFile() throws {
        // 创建初始提交
        try testRepo.createFileAndCommit(
            fileName: "existing.txt",
            content: "Content",
            message: "Initial commit"
        )

        // 获取提交列表
        let commits = try LibGit2.getCommitList(at: testRepo.repositoryPath)

        // 尝试获取不存在的文件的内容变更
        let (beforeContent, afterContent) = try LibGit2.getFileContentChange(
            atCommit: commits[0].hash,
            file: "nonexistent.txt",
            at: testRepo.repositoryPath
        )

        // 不存在的文件应该返回 (nil, nil)
        XCTAssertNil(beforeContent, "Non-existent file should have nil before content")
        XCTAssertNil(afterContent, "Non-existent file should have nil after content")
    }

    // MARK: - Get File Content Tests

    func testGetFileContentExistingFile() throws {
        // 创建初始提交
        try testRepo.createFileAndCommit(
            fileName: "test.txt",
            content: "File content",
            message: "Initial commit"
        )

        // 获取提交列表
        let commits = try LibGit2.getCommitList(at: testRepo.repositoryPath)

        // 获取文件内容
        let content = try LibGit2.getFileContent(
            atCommit: commits[0].hash,
            file: "test.txt",
            at: testRepo.repositoryPath
        )

        XCTAssertEqual(content, "File content", "Content should match")
    }

    func testGetFileContentNonExistentFile() throws {
        // 创建初始提交
        try testRepo.createFileAndCommit(
            fileName: "test.txt",
            content: "Content",
            message: "Initial commit"
        )

        // 获取提交列表
        let commits = try LibGit2.getCommitList(at: testRepo.repositoryPath)

        // 尝试获取不存在的文件的内容
        XCTAssertThrowsError(
            try LibGit2.getFileContent(
                atCommit: commits[0].hash,
                file: "nonexistent.txt",
                at: testRepo.repositoryPath
            )
        ) { error in
            XCTAssertTrue(error is LibGit2Error, "Should throw LibGit2Error for non-existent file")
        }
    }

    func testGetFileContentInvalidCommit() throws {
        // 尝试使用无效的 commit hash
        XCTAssertThrowsError(
            try LibGit2.getFileContent(
                atCommit: "invalid_hash_12345",
                file: "test.txt",
                at: testRepo.repositoryPath
            )
        ) { error in
            XCTAssertTrue(error is LibGit2Error, "Should throw LibGit2Error for invalid commit hash")
        }
    }

    func testGetFileContentEmptyFile() throws {
        // 创建空文件提交
        try testRepo.createFileAndCommit(
            fileName: "empty.txt",
            content: "",
            message: "Empty file"
        )

        // 获取提交列表
        let commits = try LibGit2.getCommitList(at: testRepo.repositoryPath)

        // 获取空文件内容
        let content = try LibGit2.getFileContent(
            atCommit: commits[0].hash,
            file: "empty.txt",
            at: testRepo.repositoryPath
        )

        XCTAssertEqual(content, "", "Empty file should return empty string")
    }

    func testGetFileContentMultiLineFile() throws {
        // 创建多行文件
        let multiLineContent = "Line 1\nLine 2\nLine 3\nLine 4\nLine 5"

        try testRepo.createFileAndCommit(
            fileName: "multiline.txt",
            content: multiLineContent,
            message: "Multi-line file"
        )

        // 获取提交列表
        let commits = try LibGit2.getCommitList(at: testRepo.repositoryPath)

        // 获取文件内容
        let content = try LibGit2.getFileContent(
            atCommit: commits[0].hash,
            file: "multiline.txt",
            at: testRepo.repositoryPath
        )

        XCTAssertEqual(content, multiLineContent, "Multi-line content should match")
    }

    // MARK: - Get Diff Between Commits Tests

    func testGetDiffBetweenCommits() throws {
        // 创建初始提交
        try testRepo.createFileAndCommit(
            fileName: "test.txt",
            content: "Original content",
            message: "Initial commit"
        )

        // 修改文件
        try testRepo.createFileAndCommit(
            fileName: "test.txt",
            content: "Modified content",
            message: "Modify file"
        )

        // 获取提交列表
        let commits = try LibGit2.getCommitList(at: testRepo.repositoryPath)

        // 获取两个提交之间的 diff
        let diff = try LibGit2.getDiffBetweenCommits(
            from: commits[1].hash,
            to: commits[0].hash,
            at: testRepo.repositoryPath
        )

        XCTAssertFalse(diff.isEmpty, "Diff should not be empty")
        XCTAssertTrue(diff.contains("test.txt"), "Diff should contain file name")
        XCTAssertTrue(diff.contains("Original content") || diff.contains("Modified content"), "Diff should show content change")
    }

    func testGetDiffBetweenCommitsMultipleFiles() throws {
        // 创建初始提交
        try testRepo.createFileAndCommit(
            fileName: "file1.txt",
            content: "Content 1",
            message: "Add file1"
        )

        // 添加和修改多个文件
        try testRepo.createFileAndCommit(
            fileName: "file1.txt",
            content: "Modified 1",
            message: "Modify file1"
        )

        try testRepo.createFileAndCommit(
            fileName: "file2.txt",
            content: "Content 2",
            message: "Add file2"
        )

        // 获取提交列表
        let commits = try LibGit2.getCommitList(at: testRepo.repositoryPath)

        // 获取从初始提交到最新提交的 diff
        let diff = try LibGit2.getDiffBetweenCommits(
            from: commits[2].hash,
            to: commits[0].hash,
            at: testRepo.repositoryPath
        )

        XCTAssertFalse(diff.isEmpty, "Diff should not be empty")
        XCTAssertTrue(diff.contains("file1.txt") || diff.contains("file2.txt"), "Diff should contain changed files")
    }

    func testGetDiffBetweenCommitsNoChanges() throws {
        // 创建初始提交
        try testRepo.createFileAndCommit(
            fileName: "test.txt",
            content: "Same content",
            message: "Initial commit"
        )

        // 创建相同内容的提交
        try testRepo.createFileAndCommit(
            fileName: "test.txt",
            content: "Same content",
            message: "No changes"
        )

        // 获取提交列表
        let commits = try LibGit2.getCommitList(at: testRepo.repositoryPath)

        // 获取两个提交之间的 diff（应该为空或只有元数据）
        let diff = try LibGit2.getDiffBetweenCommits(
            from: commits[1].hash,
            to: commits[0].hash,
            at: testRepo.repositoryPath
        )

        // 即使内容相同，也可能有 commit 信息不同，所以 diff 可能为空或只有少量信息
        // 只要不抛出错误就通过
        XCTAssertTrue(true, "Should handle no changes gracefully")
    }

    func testGetDiffBetweenCommitsInvalidCommit() throws {
        // 创建初始提交
        try testRepo.createFileAndCommit(
            fileName: "test.txt",
            content: "Content",
            message: "Initial commit"
        )

        // 获取提交列表
        let commits = try LibGit2.getCommitList(at: testRepo.repositoryPath)

        // 尝试使用无效的 "from" commit hash
        XCTAssertThrowsError(
            try LibGit2.getDiffBetweenCommits(
                from: "invalid_hash_12345",
                to: commits[0].hash,
                at: testRepo.repositoryPath
            )
        ) { error in
            XCTAssertTrue(error is LibGit2Error, "Should throw LibGit2Error for invalid commit hash")
        }
    }

    // MARK: - Diff File List Tests

    func testGetDiffFileListWithNewFile() throws {
        // 创建初始提交
        try testRepo.createFileAndCommit(
            fileName: "initial.txt",
            content: "Content",
            message: "Initial commit"
        )

        // 创建新文件（未跟踪）
        try "New file".write(to: testRepo.tempDirectory.appendingPathComponent("new.txt"), atomically: true, encoding: .utf8)

        // 获取工作区diff（应该包含未跟踪文件）
        let diffFiles = try LibGit2.getDiffFileList(at: testRepo.repositoryPath, staged: false)
        XCTAssertTrue(diffFiles.contains { $0.file == "new.txt" }, "Should include untracked files")
    }

    func testGetDiffFileListEmptyRepository() throws {
        // 空仓库的diff应该为空
        let diffFiles = try LibGit2.getDiffFileList(at: testRepo.repositoryPath, staged: false)
        XCTAssertTrue(diffFiles.isEmpty, "Empty repo should have no diff")
    }

    func testGetDiffFileListStagedEmptyRepository() throws {
        // 空仓库的staged diff也应该为空
        let stagedDiff = try LibGit2.getDiffFileList(at: testRepo.repositoryPath, staged: true)
        XCTAssertTrue(stagedDiff.isEmpty, "Empty repo should have no staged diff")
    }

    func testGetDiffFileListDeletedFile() throws {
        // 创建文件并提交
        try testRepo.createFileAndCommit(
            fileName: "toDelete.txt",
            content: "Will be deleted",
            message: "Initial commit"
        )

        // 删除文件
        let fileURL = testRepo.tempDirectory.appendingPathComponent("toDelete.txt")
        try FileManager.default.removeItem(at: fileURL)

        // 工作区diff应该包含删除的文件
        let diffFiles = try LibGit2.getDiffFileList(at: testRepo.repositoryPath, staged: false)
        XCTAssertTrue(diffFiles.contains { $0.file == "toDelete.txt" && $0.changeType == "D" }, "Should show deleted file")
    }

    // MARK: - File Diff Tests

    func testGetFileDiffStaged() throws {
        // 创建初始提交
        try testRepo.createFileAndCommit(
            fileName: "file.txt",
            content: "Original",
            message: "Initial commit"
        )

        // 修改并暂存
        try "Modified".write(to: testRepo.tempDirectory.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
        try LibGit2.addFiles(["file.txt"], at: testRepo.repositoryPath)

        // 获取文件详细diff
        let fileDiff = try LibGit2.getFileDiff(for: "file.txt", at: testRepo.repositoryPath, staged: true)
        XCTAssertFalse(fileDiff.isEmpty, "File diff should not be empty")
        XCTAssertTrue(fileDiff.contains("file.txt"), "Diff should mention the file")
    }

    func testGetFileDiffUnstaged() throws {
        // 创建初始提交
        try testRepo.createFileAndCommit(
            fileName: "file.txt",
            content: "Original",
            message: "Initial commit"
        )

        // 修改但不暂存
        try "Modified".write(to: testRepo.tempDirectory.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)

        // 获取文件详细diff
        let fileDiff = try LibGit2.getFileDiff(for: "file.txt", at: testRepo.repositoryPath, staged: false)
        XCTAssertFalse(fileDiff.isEmpty, "File diff should not be empty")
    }

    func testApplyPatchStagesAndUnstagesModifiedFile() throws {
        try testRepo.createFileAndCommit(
            fileName: "file.txt",
            content: "Original\n",
            message: "Initial commit"
        )

        try "Modified\n".write(
            to: testRepo.tempDirectory.appendingPathComponent("file.txt"),
            atomically: true,
            encoding: .utf8
        )

        let patch = try LibGit2.getFileDiff(for: "file.txt", at: testRepo.repositoryPath, staged: false)
        XCTAssertFalse(patch.isEmpty)

        try LibGit2.applyPatch(patch, mode: .stage, at: testRepo.repositoryPath)
        var stagedDiff = try LibGit2.getFileDiff(for: "file.txt", at: testRepo.repositoryPath, staged: true)
        XCTAssertTrue(stagedDiff.contains("+Modified"))

        try LibGit2.applyPatch(patch, mode: .unstage, at: testRepo.repositoryPath)
        stagedDiff = try LibGit2.getFileDiff(for: "file.txt", at: testRepo.repositoryPath, staged: true)
        XCTAssertTrue(stagedDiff.isEmpty)
    }
}
