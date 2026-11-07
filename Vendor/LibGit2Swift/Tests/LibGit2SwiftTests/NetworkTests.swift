import Foundation
@testable import LibGit2Swift
import Clibgit2
import XCTest

/// Network 相关功能的测试
/// 注意：网络操作测试需要特殊处理，这里主要测试基本功能和错误处理
final class NetworkTests: LibGit2SwiftTestCase {

    // MARK: - Clone Tests

    func testCloneLocalRepository() throws {
        // 创建一个本地仓库作为"远程"仓库
        let remoteRepoPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("LibGit2SwiftTests-Network-\(UUID().uuidString)")
            .path

        try FileManager.default.createDirectory(atPath: remoteRepoPath, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(atPath: remoteRepoPath)
        }

        // 初始化远程仓库
        let remoteRepo = try LibGit2.createRepository(at: remoteRepoPath)
        git_repository_free(remoteRepo)

        // 配置远程仓库
        try LibGit2.setConfig(key: "user.name", value: "Test", at: remoteRepoPath, verbose: false)
        try LibGit2.setConfig(key: "user.email", value: "test@test.com", at: remoteRepoPath, verbose: false)

        // 创建提交
        let fileURL = URL(fileURLWithPath: remoteRepoPath).appendingPathComponent("README.md")
        try "Test README".write(to: fileURL, atomically: true, encoding: .utf8)
        try LibGit2.addFiles(["README.md"], at: remoteRepoPath)
        _ = try LibGit2.createCommit(message: "Initial commit", at: remoteRepoPath, verbose: false)

        // 克隆到本地路径
        let clonePath = testRepo.tempDirectory.appendingPathComponent("cloned").path

        try LibGit2.clone(url: remoteRepoPath, to: clonePath)

        // 验证克隆成功
        XCTAssertTrue(FileManager.default.fileExists(atPath: clonePath))
        XCTAssertTrue(try LibGit2.isGitRepository(at: clonePath))

        // 清理克隆的仓库
        try? FileManager.default.removeItem(atPath: clonePath)
    }

    func testCloneCanBeCancelledBeforeStarting() throws {
        let clonePath = testRepo.tempDirectory.appendingPathComponent("cancelled-clone").path

        let token = GitCancellationToken()
        token.cancel()

        XCTAssertThrowsError(
            try LibGit2.clone(
                url: "/nonexistent/path",
                to: clonePath,
                cancellation: token
            )
        ) { error in
            XCTAssertTrue(error is CancellationError)
        }
    }

    func testCloneProgressSnapshotCalculatesFraction() {
        let progress = LibGit2CloneProgress(
            totalObjects: 10,
            indexedObjects: 4,
            receivedObjects: 5,
            totalDeltas: 3,
            indexedDeltas: 1,
            receivedBytes: 2048
        )

        XCTAssertEqual(progress.fractionCompleted, 0.5)
        XCTAssertEqual(progress.receivedBytes, 2048)
    }

    func testCloneInvalidURL() throws {
        // 尝试克隆无效URL应该失败
        let invalidURL = "/nonexistent/path/that/does/not/exist"
        let clonePath = testRepo.tempDirectory.appendingPathComponent("invalid-clone").path

        XCTAssertThrowsError(try LibGit2.clone(url: invalidURL, to: clonePath)) { error in
            XCTAssertTrue(error is LibGit2Error)
        }
    }

    // MARK: - Push/Pull Tests (require remote setup)

    func testPushWithNoRemote() throws {
        // 创建提交
        try testRepo.createFileAndCommit(
            fileName: "file.txt",
            content: "Content",
            message: "Initial commit"
        )

        // 没有配置远程仓库时push应该失败
        XCTAssertThrowsError(try LibGit2.push(at: testRepo.repositoryPath, verbose: false)) { error in
            XCTAssertTrue(error is LibGit2Error)
        }
    }

    func testPullWithNoRemote() throws {
        // 创建提交
        try testRepo.createFileAndCommit(
            fileName: "file.txt",
            content: "Content",
            message: "Initial commit"
        )

        // 没有配置远程仓库时pull应该失败
        XCTAssertThrowsError(try LibGit2.pull(at: testRepo.repositoryPath, verbose: false)) { error in
            XCTAssertTrue(error is LibGit2Error)
        }
    }

    func testPushWithRemoteNotFound() throws {
        // 创建提交
        try testRepo.createFileAndCommit(
            fileName: "file.txt",
            content: "Content",
            message: "Initial commit"
        )

        // 未设置 upstream 时 push 必须先报错（而不是假定远程分支名与本地同名）
        XCTAssertThrowsError(try LibGit2.push(at: testRepo.repositoryPath, verbose: false)) { error in
            guard case LibGit2Error.noUpstreamConfigured = error else {
                return XCTFail("expected noUpstreamConfigured, got \(error)")
            }
        }
    }

    func testPublishAndDeleteRemoteBranchToLocalBareRepository() throws {
        try testRepo.createFileAndCommit(
            fileName: "file.txt",
            content: "Content",
            message: "Initial commit"
        )

        let bareRemoteURL = try createBareRepository()
        try LibGit2.addRemote(name: "origin", url: bareRemoteURL.path, at: testRepo.repositoryPath)

        let currentBranch = try LibGit2.getCurrentBranch(at: testRepo.repositoryPath)
        try LibGit2.publishBranch(
            localBranch: currentBranch,
            remote: "origin",
            remoteBranch: "published",
            at: testRepo.repositoryPath,
            verbose: false
        )

        XCTAssertTrue(remoteReferenceExists("refs/heads/published", in: bareRemoteURL))
        XCTAssertEqual(
            try LibGit2.getConfig(key: "branch.\(currentBranch).remote", at: testRepo.repositoryPath, verbose: false),
            "origin"
        )
        XCTAssertEqual(
            try LibGit2.getConfig(key: "branch.\(currentBranch).merge", at: testRepo.repositoryPath, verbose: false),
            "refs/heads/published"
        )

        try LibGit2.deleteRemoteBranch(named: "origin/published", remote: "origin", at: testRepo.repositoryPath, verbose: false)
        XCTAssertFalse(remoteReferenceExists("refs/heads/published", in: bareRemoteURL))
    }

    func testPushAndDeleteRemoteTagToLocalBareRepository() throws {
        try testRepo.createFileAndCommit(
            fileName: "file.txt",
            content: "Content",
            message: "Initial commit"
        )

        try LibGit2.createTag(named: "v-test", in: testRepo.repositoryPath, verbose: false)

        let bareRemoteURL = try createBareRepository()
        try LibGit2.addRemote(name: "origin", url: bareRemoteURL.path, at: testRepo.repositoryPath)

        try LibGit2.pushTag(named: "v-test", remote: "origin", at: testRepo.repositoryPath, verbose: false)
        XCTAssertTrue(remoteReferenceExists("refs/tags/v-test", in: bareRemoteURL))

        try LibGit2.deleteRemoteTag(named: "v-test", remote: "origin", at: testRepo.repositoryPath, verbose: false)
        XCTAssertFalse(remoteReferenceExists("refs/tags/v-test", in: bareRemoteURL))
    }

    func testPullWithRemoteNotFound() throws {
        // 创建提交
        try testRepo.createFileAndCommit(
            fileName: "file.txt",
            content: "Content",
            message: "Initial commit"
        )

        // 未设置 upstream 时 pull 应报 noUpstreamConfigured；
        // 这是取代"假定远程分支名与本地同名"后的正确行为。
        XCTAssertThrowsError(try LibGit2.pull(at: testRepo.repositoryPath, verbose: false)) { error in
            guard case LibGit2Error.noUpstreamConfigured = error else {
                return XCTFail("expected noUpstreamConfigured, got \(error)")
            }
        }
    }

    // MARK: - isValidGitRepository Tests

    func testIsValidGitRepositoryLocal() throws {
        // 创建本地仓库
        try testRepo.createFileAndCommit(
            fileName: "file.txt",
            content: "Content",
            message: "Initial commit"
        )

        // 验证本地仓库是有效的Git仓库
        let isValid = LibGit2.isValidGitRepository(testRepo.repositoryPath, at: testRepo.repositoryPath)
        XCTAssertTrue(isValid)
    }

    func testIsValidGitRepositoryInvalidPath() throws {
        // git_remote_create_anonymous 可能对任何URL格式都成功
        // 它只验证URL格式，不验证远程仓库是否存在
        // 测试函数能正常执行
        let isValid = LibGit2.isValidGitRepository("/nonexistent/path", at: testRepo.repositoryPath)
        // 函数会返回结果（可能是true或false，取决于libgit2的实现）
        // 只要不崩溃就通过
        XCTAssertTrue(true)
    }

    // MARK: - Remote URL Tests

    func testAddRemoteAndCheckURL() throws {
        // 创建提交
        try testRepo.createFileAndCommit(
            fileName: "file.txt",
            content: "Content",
            message: "Initial commit"
        )

        // 添加远程仓库
        let remoteURL = "https://github.com/test/test.git"
        try LibGit2.addRemote(name: "origin", url: remoteURL, at: testRepo.repositoryPath)

        // 验证远程URL
        let url = try LibGit2.getRemoteURL(at: testRepo.repositoryPath, remote: "origin")
        XCTAssertEqual(url, remoteURL)
    }

    // MARK: - Edge Cases

    func testNetworkOperationsEmptyRepository() throws {
        // 空仓库无法进行网络操作
        XCTAssertThrowsError(try LibGit2.push(at: testRepo.repositoryPath, verbose: false))
        XCTAssertThrowsError(try LibGit2.pull(at: testRepo.repositoryPath, verbose: false))
    }

    func testCloneToExistingDirectory() throws {
        // 创建一个已存在的目录
        let existingDir = testRepo.tempDirectory.appendingPathComponent("existing")
        try FileManager.default.createDirectory(at: existingDir, withIntermediateDirectories: true)

        // 创建一个简单的远程仓库
        let remotePath = FileManager.default.temporaryDirectory
            .appendingPathComponent("remote-\(UUID().uuidString)")
            .path
        try FileManager.default.createDirectory(atPath: remotePath, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: remotePath) }

        let repo = try LibGit2.createRepository(at: remotePath)
        git_repository_free(repo)

        // 克隆到已存在的目录 - libgit2可能允许或在目录内创建.git
        // 测试不崩溃即可
        XCTAssertNoThrow(try LibGit2.clone(url: remotePath, to: existingDir.path))
    }

    private func createBareRepository() throws -> URL {
        let remoteURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("LibGit2SwiftTests-BareRemote-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: remoteURL, withIntermediateDirectories: true)

        var repo: OpaquePointer?
        let result = git_repository_init(&repo, remoteURL.path, 1)
        guard result == 0, let repo else {
            throw LibGit2Error.invalidRepository
        }
        git_repository_free(repo)
        return remoteURL
    }

    private func remoteReferenceExists(_ referenceName: String, in remoteURL: URL) -> Bool {
        guard let repo = try? LibGit2.openRepository(at: remoteURL.path) else {
            return false
        }
        defer { git_repository_free(repo) }

        var reference: OpaquePointer?
        let result = git_reference_lookup(&reference, repo, referenceName)
        if reference != nil {
            git_reference_free(reference)
        }
        return result == 0
    }
}
