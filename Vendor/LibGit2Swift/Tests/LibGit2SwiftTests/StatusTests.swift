import Foundation
@testable import LibGit2Swift
import XCTest

/// Status 相关功能的测试
final class StatusTests: LibGit2SwiftTestCase {
    // MARK: - Basic Status Tests

    func testCancellableRepositoryStatusHonorsPreCancelledToken() throws {
        let cancellation = GitCancellationToken()
        cancellation.cancel()

        XCTAssertThrowsError(
            try LibGit2.getRepositoryStatus(
                at: testRepo.repositoryPath,
                cancellation: cancellation
            )
        ) { error in
            XCTAssertTrue(error is CancellationError)
        }
    }

    func testCancellableStatusEntriesPreserveFileStatuses() throws {
        try testRepo.createFileAndCommit(
            fileName: "tracked.txt",
            content: "Original",
            message: "Initial commit"
        )

        try "Modified".write(
            to: testRepo.tempDirectory.appendingPathComponent("tracked.txt"),
            atomically: true,
            encoding: .utf8
        )
        try "Untracked".write(
            to: testRepo.tempDirectory.appendingPathComponent("untracked.txt"),
            atomically: true,
            encoding: .utf8
        )

        let entries = try LibGit2.getStatusEntries(
            at: testRepo.repositoryPath,
            cancellation: GitCancellationToken()
        )

        XCTAssertEqual(
            entries,
            [
                GitRepositoryStatusEntry(
                    path: "tracked.txt",
                    stagedStatus: " ",
                    worktreeStatus: "M"
                ),
                GitRepositoryStatusEntry(
                    path: "untracked.txt",
                    stagedStatus: "?",
                    worktreeStatus: "?"
                ),
            ]
        )
    }

    func testCancellableQueueWaitSkipsWorkAfterCancellation() throws {
        let queue = LibGit2QueuePool.shared
        let entered = DispatchSemaphore(value: 0)
        let blockerFinished = DispatchSemaphore(value: 0)
        let repositoryPath = testRepo.repositoryPath

        DispatchQueue.global(qos: .userInitiated).async {
            queue.sync(repositoryPath: repositoryPath) {
                entered.signal()
                Thread.sleep(forTimeInterval: 0.4)
            }
            blockerFinished.signal()
        }

        XCTAssertEqual(entered.wait(timeout: .now() + 1), .success)

        let cancellation = GitCancellationToken()
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.03) {
            cancellation.cancel()
        }

        let start = Date()
        XCTAssertThrowsError(
            try queue.sync(repositoryPath: repositoryPath, cancellation: cancellation) {
                XCTFail("A cancelled queued task must not enter its body")
            }
        ) { error in
            XCTAssertTrue(error is CancellationError)
        }
        XCTAssertLessThan(Date().timeIntervalSince(start), 0.2)
        XCTAssertEqual(blockerFinished.wait(timeout: .now() + 1), .success)
    }

    func testCancellableStatusStopsDuringLargeUntrackedScan() throws {
        let fileManager = FileManager.default
        for directoryIndex in 0..<40 {
            let directory = testRepo.tempDirectory
                .appendingPathComponent("untracked-\(directoryIndex)", isDirectory: true)
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            for fileIndex in 0..<100 {
                let file = directory.appendingPathComponent("file-\(fileIndex).txt")
                XCTAssertTrue(fileManager.createFile(atPath: file.path, contents: Data()))
            }
        }

        let cancellation = GitCancellationToken()
        let finished = expectation(description: "status scan finishes")
        var result: Result<[GitRepositoryStatusEntry], Error>?

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                result = .success(try LibGit2.getStatusEntries(
                    at: self.testRepo.repositoryPath,
                    cancellation: cancellation
                ))
            } catch {
                result = .failure(error)
            }
            finished.fulfill()
        }

        // 4,000 files make it very unlikely that the native scan has completed
        // before this cancellation reaches the progress callback.
        Thread.sleep(forTimeInterval: 0.01)
        cancellation.cancel()
        wait(for: [finished], timeout: 5)

        guard let result else {
            return XCTFail("status scan did not produce a result")
        }
        guard case let .failure(error) = result else {
            return XCTFail("large untracked scan completed before cancellation")
        }
        XCTAssertTrue(error is CancellationError)
    }

    func testHasUncommittedChangesEmptyRepository() throws {
        // 空仓库应该没有未提交的更改
        let hasChanges = try LibGit2.hasUncommittedChanges(at: testRepo.repositoryPath)
        XCTAssertFalse(hasChanges, "Empty repository should not have uncommitted changes")
    }

    func testHasUncommittedChangesWithUntrackedFile() throws {
        // 创建未跟踪的文件
        let fileName = TestDataGenerator.randomFileName()
        let content = TestDataGenerator.testContent()

        let fileURL = testRepo.tempDirectory.appendingPathComponent(fileName)
        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        // 未跟踪的文件不应该算作"未提交的更改"
        // 只有已跟踪文件的修改、暂存等才算
        let hasChanges = try LibGit2.hasUncommittedChanges(at: testRepo.repositoryPath)
        XCTAssertFalse(hasChanges, "Repository with only untracked files should not have uncommitted changes")
    }

    func testHasUncommittedChangesWithModifiedFile() throws {
        // 创建并提交一个文件
        let fileName = TestDataGenerator.randomFileName()
        try testRepo.createFileAndCommit(
            fileName: fileName,
            content: "Original content",
            message: "Initial commit"
        )

        // 修改文件
        let fileURL = testRepo.tempDirectory.appendingPathComponent(fileName)
        try "Modified content".write(to: fileURL, atomically: true, encoding: .utf8)

        // 应该检测到未提交的更改
        let hasChanges = try LibGit2.hasUncommittedChanges(at: testRepo.repositoryPath)
        XCTAssertTrue(hasChanges, "Repository with modified files should have uncommitted changes")
    }

    func testHasUncommittedChangesCleanRepository() throws {
        // 创建并提交文件
        try testRepo.createFileAndCommit(
            fileName: "file1.txt",
            content: "Content 1",
            message: "Commit 1"
        )

        try testRepo.createFileAndCommit(
            fileName: "file2.txt",
            content: "Content 2",
            message: "Commit 2"
        )

        // 干净的仓库应该没有未提交的更改
        let hasChanges = try LibGit2.hasUncommittedChanges(at: testRepo.repositoryPath)
        XCTAssertFalse(hasChanges, "Clean repository should not have uncommitted changes")
    }

    // MARK: - Status Detail Tests

    func testGetStatus() throws {
        // 创建初始提交
        try testRepo.createFileAndCommit(
            fileName: "initial.txt",
            content: "Initial",
            message: "Initial commit"
        )

        // 创建未跟踪的文件
        let untrackedFile = "untracked.txt"
        let fileURL = testRepo.tempDirectory.appendingPathComponent(untrackedFile)
        try "Untracked content".write(to: fileURL, atomically: true, encoding: .utf8)

        // 获取状态
        let status = try LibGit2.getStatus(at: testRepo.repositoryPath)

        XCTAssertFalse(status.isEmpty, "Status should not be empty")
        XCTAssertTrue(status.contains("??"), "Status should show untracked files")
    }

    // MARK: - Staged Files Tests

    func testGetStagedFiles() throws {
        // 创建初始提交
        try testRepo.createFileAndCommit(
            fileName: "initial.txt",
            content: "Initial",
            message: "Initial commit"
        )

        // 创建并暂存新文件
        let newFile = "newfile.txt"
        let fileURL = testRepo.tempDirectory.appendingPathComponent(newFile)
        try "New file content".write(to: fileURL, atomically: true, encoding: .utf8)

        try LibGit2.addFiles([newFile], at: testRepo.repositoryPath)

        // 获取已暂存的文件
        let stagedFiles = try LibGit2.getStagedFiles(at: testRepo.repositoryPath)

        XCTAssertTrue(stagedFiles.contains(newFile),
                      "Staged files should contain the newly added file")
    }

    func testGetStagedFilesNoStagedChanges() throws {
        // 创建初始提交
        try testRepo.createFileAndCommit(
            fileName: "initial.txt",
            content: "Initial",
            message: "Initial commit"
        )

        // 获取已暂存的文件
        let stagedFiles = try LibGit2.getStagedFiles(at: testRepo.repositoryPath)

        XCTAssertTrue(stagedFiles.isEmpty, "Should have no staged files in clean repository")
    }

    // MARK: - Unstaged Files Tests

    func testGetUnstagedFiles() throws {
        // 创建初始提交
        try testRepo.createFileAndCommit(
            fileName: "initial.txt",
            content: "Original content",
            message: "Initial commit"
        )

        // 修改文件但不暂存
        let fileURL = testRepo.tempDirectory.appendingPathComponent("initial.txt")
        try "Modified content".write(to: fileURL, atomically: true, encoding: .utf8)

        // 获取未暂存的文件
        let unstagedFiles = try LibGit2.getUnstagedFiles(at: testRepo.repositoryPath)

        XCTAssertTrue(unstagedFiles.contains("initial.txt"),
                      "Unstaged files should contain the modified file")
    }

    // MARK: - Files to Commit Tests

    func testHasFilesToCommitWithStaged() throws {
        // 创建初始提交
        try testRepo.createFileAndCommit(
            fileName: "initial.txt",
            content: "Initial",
            message: "Initial commit"
        )

        // 创建并暂存新文件
        let newFile = "newfile.txt"
        let fileURL = testRepo.tempDirectory.appendingPathComponent(newFile)
        try "New file content".write(to: fileURL, atomically: true, encoding: .utf8)

        try LibGit2.addFiles([newFile], at: testRepo.repositoryPath)

        // 检查是否有待提交的文件
        let hasFilesToCommit = try LibGit2.hasFilesToCommit(at: testRepo.repositoryPath)
        XCTAssertTrue(hasFilesToCommit, "Should have files to commit after staging")
    }

    func testHasFilesToCommitClean() throws {
        // 创建初始提交
        try testRepo.createFileAndCommit(
            fileName: "initial.txt",
            content: "Initial",
            message: "Initial commit"
        )

        // 检查是否有待提交的文件
        let hasFilesToCommit = try LibGit2.hasFilesToCommit(at: testRepo.repositoryPath)
        XCTAssertFalse(hasFilesToCommit, "Should not have files to commit in clean repository")
    }

    // MARK: - Porcelain Status Tests

    func testGetStatusPorcelain() throws {
        // 创建初始提交
        try testRepo.createFileAndCommit(
            fileName: "initial.txt",
            content: "Initial",
            message: "Initial commit"
        )

        // 创建未跟踪文件
        let untrackedFile = "untracked.txt"
        let fileURL = testRepo.tempDirectory.appendingPathComponent(untrackedFile)
        try "Untracked content".write(to: fileURL, atomically: true, encoding: .utf8)

        // 获取 porcelain 状态
        let status = try LibGit2.getStatusPorcelain(at: testRepo.repositoryPath)

        XCTAssertFalse(status.isEmpty, "Porcelain status should not be empty")
        XCTAssertTrue(status.contains("??"), "Porcelain status should show untracked files")
    }

    // MARK: - Complex Scenarios

    func testMixedStatus() throws {
        // 创建初始提交
        try testRepo.createFileAndCommit(
            fileName: "file1.txt",
            content: "Content 1",
            message: "Initial commit"
        )

        // 场景 1: 修改已有文件
        let file1URL = testRepo.tempDirectory.appendingPathComponent("file1.txt")
        try "Modified content 1".write(to: file1URL, atomically: true, encoding: .utf8)

        // 场景 2: 创建新文件并暂存
        let file2Name = "file2.txt"
        let file2URL = testRepo.tempDirectory.appendingPathComponent(file2Name)
        try "Content 2".write(to: file2URL, atomically: true, encoding: .utf8)
        try LibGit2.addFiles([file2Name], at: testRepo.repositoryPath)

        // 场景 3: 创建另一个未跟踪文件
        let file3Name = "file3.txt"
        let file3URL = testRepo.tempDirectory.appendingPathComponent(file3Name)
        try "Content 3".write(to: file3URL, atomically: true, encoding: .utf8)

        // 验证状态
        let hasChanges = try LibGit2.hasUncommittedChanges(at: testRepo.repositoryPath)
        XCTAssertTrue(hasChanges, "Should detect uncommitted changes")

        let stagedFiles = try LibGit2.getStagedFiles(at: testRepo.repositoryPath)
        XCTAssertTrue(stagedFiles.contains(file2Name), "Should contain staged file")

        let unstagedFiles = try LibGit2.getUnstagedFiles(at: testRepo.repositoryPath)
        XCTAssertTrue(unstagedFiles.contains("file1.txt"), "Should contain modified file")
    }

    func testTypedRepositoryStatusIncludesStagedUnstagedAndUntrackedFiles() throws {
        try testRepo.createFileAndCommit(
            fileName: "tracked.txt",
            content: "Original",
            message: "Initial commit"
        )

        try "Modified".write(
            to: testRepo.tempDirectory.appendingPathComponent("tracked.txt"),
            atomically: true,
            encoding: .utf8
        )
        try "Staged".write(
            to: testRepo.tempDirectory.appendingPathComponent("staged.txt"),
            atomically: true,
            encoding: .utf8
        )
        try LibGit2.addFiles(["staged.txt"], at: testRepo.repositoryPath)
        try "Untracked".write(
            to: testRepo.tempDirectory.appendingPathComponent("untracked.txt"),
            atomically: true,
            encoding: .utf8
        )

        let cancellation = GitCancellationToken()
        let entries = try LibGit2.getStatusEntries(
            at: testRepo.repositoryPath,
            cancellation: cancellation
        )
        XCTAssertEqual(Set(entries.map(\.path)), ["tracked.txt", "staged.txt", "untracked.txt"])
        XCTAssertEqual(entries.first(where: { $0.path == "tracked.txt" })?.worktreeStatus, "M")
        XCTAssertEqual(entries.first(where: { $0.path == "staged.txt" })?.stagedStatus, "A")
        XCTAssertTrue(entries.first(where: { $0.path == "untracked.txt" })?.isUntracked == true)

        let summary = try LibGit2.getRepositoryStatus(
            at: testRepo.repositoryPath,
            cancellation: cancellation
        )
        XCTAssertFalse(summary.isClean)
        XCTAssertEqual(summary.changeCount, 3)
        XCTAssertNotNil(summary.branch)
    }

    func testTypedRepositoryStatusMapsRenamesToTheNewPath() throws {
        try testRepo.createFileAndCommit(
            fileName: "old.txt",
            content: "rename me",
            message: "Initial commit"
        )

        let oldURL = testRepo.tempDirectory.appendingPathComponent("old.txt")
        let newURL = testRepo.tempDirectory.appendingPathComponent("new.txt")
        try FileManager.default.moveItem(at: oldURL, to: newURL)
        try LibGit2.addFiles([], at: testRepo.repositoryPath)

        let entries = try LibGit2.getStatusEntries(
            at: testRepo.repositoryPath,
            cancellation: GitCancellationToken()
        )
        let entry = try XCTUnwrap(entries.first)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entry.path, "new.txt")
        XCTAssertEqual(entry.stagedStatus, "R")
        XCTAssertEqual(entry.worktreeStatus, " ")
    }

    func testDiscardAllChangesRestoresTrackedFilesAndPreservesIgnoredFiles() throws {
        try testRepo.createFileAndCommit(
            fileName: ".gitignore",
            content: "ignored.txt\n",
            message: "Add ignore rules"
        )
        try testRepo.createFileAndCommit(
            fileName: "tracked.txt",
            content: "Original",
            message: "Add tracked file"
        )

        try "Modified".write(
            to: testRepo.tempDirectory.appendingPathComponent("tracked.txt"),
            atomically: true,
            encoding: .utf8
        )
        try "Staged new".write(
            to: testRepo.tempDirectory.appendingPathComponent("staged.txt"),
            atomically: true,
            encoding: .utf8
        )
        try LibGit2.addFiles(["staged.txt"], at: testRepo.repositoryPath)
        try "Untracked".write(
            to: testRepo.tempDirectory.appendingPathComponent("untracked.txt"),
            atomically: true,
            encoding: .utf8
        )
        try "Ignored".write(
            to: testRepo.tempDirectory.appendingPathComponent("ignored.txt"),
            atomically: true,
            encoding: .utf8
        )

        try LibGit2.discardAllChanges(at: testRepo.repositoryPath, verbose: false)

        XCTAssertEqual(try testRepo.readFile("tracked.txt"), "Original")
        assertFileNotExists("staged.txt", in: testRepo)
        assertFileNotExists("untracked.txt", in: testRepo)
        assertFileExists("ignored.txt", in: testRepo)
        XCTAssertTrue(try LibGit2.getRepositoryStatus(at: testRepo.repositoryPath).isClean)
    }
}
