import Foundation
@testable import LibGit2Swift
import Clibgit2
import XCTest

/// Repository 相关功能的测试
final class RepositoryTests: LibGit2SwiftTestCase {
    // MARK: - Repository Detection Tests

    func testIsGitRepositoryValid() throws {
        // 创建的测试仓库应该被识别为 Git 仓库
        let isValid = try LibGit2.isGitRepository(at: testRepo.repositoryPath)
        XCTAssertTrue(isValid, "Created repository should be a valid Git repository")
    }

    func testIsGitRepositoryInvalid() throws {
        // 创建一个非 Git 目录
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("LibGit2SwiftTests")
            .appendingPathComponent("invalid_\(UUID().uuidString)")

        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        let isValid = try LibGit2.isGitRepository(at: tempDir.path)
        XCTAssertFalse(isValid, "Non-Git directory should not be recognized as a Git repository")
    }

    func testGetRepositoryRoot() throws {
        // 创建子目录
        let subDir = testRepo.tempDirectory.appendingPathComponent("subdirectory")
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)

        // 从子目录获取仓库根目录
        let rootPath = LibGit2.repositoryRoot(at: subDir.path)

        XCTAssertNotNil(rootPath, "Repository root should not be nil")

        // 处理 macOS 路径差异（/private/var vs /var）
        let normalizedRootPath = rootPath?.replacingOccurrences(of: "/private", with: "")
        let normalizedExpected = testRepo.repositoryPath.replacingOccurrences(of: "/private", with: "")

        XCTAssertEqual(normalizedRootPath, normalizedExpected,
                      "Repository root should be the test repository path")
    }

    func testIsRepositoryEmpty() throws {
        // 新创建的仓库应该是空的
        let isEmpty = try LibGit2.isEmptyRepository(at: testRepo.repositoryPath)
        XCTAssertTrue(isEmpty, "Newly created repository should be empty")

        // 创建一个提交后，仓库应该不再是空的
        try testRepo.createFileAndCommit(
            fileName: "test.txt",
            content: "Test content",
            message: "Initial commit"
        )

        let isNotEmpty = try LibGit2.isEmptyRepository(at: testRepo.repositoryPath)
        XCTAssertFalse(isNotEmpty, "Repository with commits should not be empty")
    }

    func testGetGitDirectory() throws {
        let gitDir = try LibGit2.gitDirectory(at: testRepo.repositoryPath)

        let expectedGitDir = testRepo.tempDirectory.appendingPathComponent(".git").path

        // 处理 macOS 路径差异（/private/var vs /var 和结尾斜杠）
        let normalizedGitDir = gitDir.replacingOccurrences(of: "/private", with: "")
        let normalizedExpected = expectedGitDir.replacingOccurrences(of: "/private", with: "")

        // 移除结尾斜杠进行比较
        let finalGitDir = normalizedGitDir.hasSuffix("/") ? String(normalizedGitDir.dropLast()) : normalizedGitDir
        let finalExpected = normalizedExpected.hasSuffix("/") ? String(normalizedExpected.dropLast()) : normalizedExpected

        XCTAssertEqual(finalGitDir, finalExpected, "Git directory path should be correct")
    }

    func testTrackedFilePathsReadsHEADTree() throws {
        let nestedDirectory = testRepo.tempDirectory.appendingPathComponent("Sources")
        try FileManager.default.createDirectory(at: nestedDirectory, withIntermediateDirectories: true)
        try "let value = 1\n".write(
            to: nestedDirectory.appendingPathComponent("App.swift"),
            atomically: true,
            encoding: .utf8
        )
        try "# README\n".write(
            to: testRepo.tempDirectory.appendingPathComponent("README.md"),
            atomically: true,
            encoding: .utf8
        )
        try LibGit2.addFiles(["Sources/App.swift", "README.md"], at: testRepo.repositoryPath)
        try LibGit2.setConfig(key: "user.name", value: "Test User", at: testRepo.repositoryPath, verbose: false)
        try LibGit2.setConfig(key: "user.email", value: "test@example.com", at: testRepo.repositoryPath, verbose: false)
        _ = try LibGit2.createCommit(message: "Add tracked files", at: testRepo.repositoryPath, verbose: false)

        XCTAssertEqual(
            Set(try LibGit2.getTrackedFilePaths(at: testRepo.repositoryPath)),
            ["README.md", "Sources/App.swift"]
        )
    }

    // MARK: - HEAD Reference Tests

    func testGetHEADReference() throws {
        // 在空仓库中，HEAD 不存在，应该抛出错误
        XCTAssertThrowsError(
            try LibGit2.getHEAD(at: testRepo.repositoryPath),
            "Getting HEAD in empty repository should fail"
        )
    }

    func testGetHEADReferenceWithCommit() throws {
        // 创建提交后检查 HEAD
        try testRepo.createFileAndCommit(
            fileName: "test.txt",
            content: "Test content",
            message: "Initial commit"
        )

        let headRef = try LibGit2.getHEAD(at: testRepo.repositoryPath)

        XCTAssertFalse(headRef.isEmpty, "HEAD reference should not be empty")
    }

    func testIsHEADDetached() throws {
        // 新仓库的 HEAD 不应该处于分离状态
        let isDetached = try LibGit2.isHEADDetached(at: testRepo.repositoryPath)
        XCTAssertFalse(isDetached, "HEAD should not be detached in new repository")
    }

    // MARK: - Current Branch Tests

    func testGetCurrentBranch() throws {
        // 在空仓库中，HEAD 不存在，应该抛出错误
        XCTAssertThrowsError(
            try LibGit2.getCurrentBranch(at: testRepo.repositoryPath),
            "Getting current branch in empty repository should fail"
        )
    }

    func testGetCurrentBranchWithCommit() throws {
        // 创建提交后获取当前分支
        try testRepo.createFileAndCommit(
            fileName: "test.txt",
            content: "Test content",
            message: "Initial commit"
        )

        let currentBranch = try LibGit2.getCurrentBranch(at: testRepo.repositoryPath)

        XCTAssertFalse(currentBranch.isEmpty, "Current branch name should not be empty")
    }

    // MARK: - Branch Detection Tests

    func testGetCurrentBranchInfo() throws {
        // 创建提交以初始化分支
        try testRepo.createFileAndCommit(
            fileName: "test.txt",
            content: "Test content",
            message: "Initial commit"
        )

        let branchInfo = try LibGit2.getCurrentBranchInfo(at: testRepo.repositoryPath)

        XCTAssertNotNil(branchInfo, "Branch info should not be nil")
        XCTAssertFalse(branchInfo?.name.isEmpty ?? true, "Branch name should not be empty")
        XCTAssertTrue(branchInfo?.isCurrent ?? false, "Branch should be marked as current")
    }

    // MARK: - Error Handling Tests

    func testInvalidPathError() throws {
        // 测试无效路径的错误处理 - isGitRepository 不会抛出错误，而是返回 false
        let isValid = LibGit2.isGitRepository(at: "/nonexistent/path/that/does/not/exist")
        XCTAssertFalse(isValid, "Non-existent path should not be a Git repository")
    }

    func testGetRepositoryRootOutsideGit() throws {
        // 在 Git 仓库外的目录获取根目录应该返回 nil
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("LibGit2SwiftTests")
            .appendingPathComponent("nongit_\(UUID().uuidString)")

        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        let rootPath = LibGit2.repositoryRoot(at: tempDir.path)
        XCTAssertNil(rootPath, "Repository root should be nil when outside Git repo")
    }

    // MARK: - Remote URL Tests

    func testGetRemoteURLNoRemote() throws {
        // 创建提交
        try testRepo.createFileAndCommit(
            fileName: "file.txt",
            content: "Content",
            message: "Initial commit"
        )

        // 没有远程仓库时，getRemoteURL应该返回nil
        let url = LibGit2.getRemoteURL(at: testRepo.repositoryPath, remote: "origin")
        XCTAssertNil(url, "Should return nil when remote doesn't exist")
    }

    func testGetRemoteURLWithRemote() throws {
        // 创建提交
        try testRepo.createFileAndCommit(
            fileName: "file.txt",
            content: "Content",
            message: "Initial commit"
        )

        // 添加远程仓库
        let remoteURL = "https://github.com/test/test.git"
        try LibGit2.addRemote(name: "origin", url: remoteURL, at: testRepo.repositoryPath)

        // 获取远程URL
        let url = LibGit2.getRemoteURL(at: testRepo.repositoryPath, remote: "origin")
        XCTAssertEqual(url, remoteURL, "Should return correct remote URL")
    }

    func testGetRemoteURLNonExistentRemote() throws {
        // 创建提交
        try testRepo.createFileAndCommit(
            fileName: "file.txt",
            content: "Content",
            message: "Initial commit"
        )

        // 获取不存在远程的URL应该返回nil
        let url = LibGit2.getRemoteURL(at: testRepo.repositoryPath, remote: "nonexistent")
        XCTAssertNil(url, "Should return nil for non-existent remote")
    }

    func testSetRemoteURL() throws {
        // 创建提交和远程
        try testRepo.createFileAndCommit(
            fileName: "file.txt",
            content: "Content",
            message: "Initial commit"
        )

        let originalURL = "https://github.com/original/test.git"
        try LibGit2.addRemote(name: "origin", url: originalURL, at: testRepo.repositoryPath)

        // 设置新的URL
        let newURL = "https://github.com/new/test.git"
        try LibGit2.setRemoteURL(at: testRepo.repositoryPath, remote: "origin", url: newURL)

        // 验证URL已更新
        let updatedURL = LibGit2.getRemoteURL(at: testRepo.repositoryPath, remote: "origin")
        XCTAssertEqual(updatedURL, newURL, "Remote URL should be updated")
    }

    func testSetRemoteURLNonExistentRemote() throws {
        // 创建提交
        try testRepo.createFileAndCommit(
            fileName: "file.txt",
            content: "Content",
            message: "Initial commit"
        )

        // 设置不存在远程的URL - libgit2可能会创建配置而不是抛出错误
        // 测试不崩溃即可
        XCTAssertNoThrow(try LibGit2.setRemoteURL(at: testRepo.repositoryPath, remote: "nonexistent", url: "https://example.com"))
    }

    // MARK: - Repository Creation Tests

    func testCreateRepositorySuccess() throws {
        // 创建新仓库应该成功
        let newRepoPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("LibGit2SwiftTests-NewRepo-\(UUID().uuidString)")
            .path

        try FileManager.default.createDirectory(atPath: newRepoPath, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(atPath: newRepoPath)
        }

        let repo = try LibGit2.createRepository(at: newRepoPath)
        git_repository_free(repo)

        // 验证仓库已创建
        XCTAssertTrue(try LibGit2.isGitRepository(at: newRepoPath))
    }

    func testCreateRepositoryInvalidPath() throws {
        // 尝试在无效路径创建仓库应该失败
        XCTAssertThrowsError(try LibGit2.createRepository(at: "/nonexistent/path")) { error in
            XCTAssertTrue(error is LibGit2Error)
        }
    }
}
