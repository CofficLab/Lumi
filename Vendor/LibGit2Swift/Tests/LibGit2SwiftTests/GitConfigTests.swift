import Foundation
@testable import LibGit2Swift
import XCTest

/// GitConfig 类测试
final class GitConfigTests: LibGit2SwiftTestCase {

    // MARK: - GitConfig Class Tests

    func testGitConfigGetUserName() throws {
        // 创建提交以初始化仓库配置
        try testRepo.createFileAndCommit(
            fileName: "file.txt",
            content: "Content",
            message: "Initial commit"
        )

        // 使用GitConfig类获取用户名
        let userName = try GitConfig.getUserName(at: testRepo.repositoryPath, verbose: false)
        XCTAssertEqual(userName, "Test User", "Should get configured user name")
    }

    func testGitConfigGetUserEmail() throws {
        // 创建提交以初始化仓库配置
        try testRepo.createFileAndCommit(
            fileName: "file.txt",
            content: "Content",
            message: "Initial commit"
        )

        // 使用GitConfig类获取用户邮箱
        let userEmail = try GitConfig.getUserEmail(at: testRepo.repositoryPath, verbose: false)
        XCTAssertEqual(userEmail, "test@example.com", "Should get configured user email")
    }

    func testGitConfigGetUserNameNotConfigured() throws {
        // 创建一个新的临时目录作为仓库（不继承testRepo的配置）
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("LibGit2SwiftTests-NoConfig-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // 在新目录创建仓库（不设置配置）
        _ = try LibGit2.createRepository(at: tempDir.path)

        // 尝试获取未配置的用户名应该失败
        XCTAssertThrowsError(try GitConfig.getUserName(at: tempDir.path, verbose: false)) { error in
            XCTAssertTrue(error is LibGit2Error)
        }
    }

    func testGitConfigGetUserEmailNotConfigured() throws {
        // 创建一个新的临时目录作为仓库（不继承testRepo的配置）
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("LibGit2SwiftTests-NoConfig-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // 在新目录创建仓库（不设置配置）
        _ = try LibGit2.createRepository(at: tempDir.path)

        // 尝试获取未配置的用户邮箱应该失败
        XCTAssertThrowsError(try GitConfig.getUserEmail(at: tempDir.path, verbose: false)) { error in
            XCTAssertTrue(error is LibGit2Error)
        }
    }

    func testGitConfigVerboseMode() throws {
        // 创建提交
        try testRepo.createFileAndCommit(
            fileName: "file.txt",
            content: "Content",
            message: "Initial commit"
        )

        // 测试verbose模式（默认）
        let userName = try GitConfig.getUserName(at: testRepo.repositoryPath)
        XCTAssertFalse(userName.isEmpty)

        let userEmail = try GitConfig.getUserEmail(at: testRepo.repositoryPath)
        XCTAssertFalse(userEmail.isEmpty)
    }

    func testGitConfigAfterConfigUpdate() throws {
        // 创建提交
        try testRepo.createFileAndCommit(
            fileName: "file.txt",
            content: "Content",
            message: "Initial commit"
        )

        // 更新配置
        try LibGit2.setConfig(key: "user.name", value: "New User", at: testRepo.repositoryPath, verbose: false)
        try LibGit2.setConfig(key: "user.email", value: "new@example.com", at: testRepo.repositoryPath, verbose: false)

        // 验证GitConfig读取到新值
        let newUserName = try GitConfig.getUserName(at: testRepo.repositoryPath, verbose: false)
        XCTAssertEqual(newUserName, "New User")

        let newUserEmail = try GitConfig.getUserEmail(at: testRepo.repositoryPath, verbose: false)
        XCTAssertEqual(newUserEmail, "new@example.com")
    }

    func testGitConfigInvalidRepository() throws {
        // 无效仓库路径应该抛出错误
        XCTAssertThrowsError(try GitConfig.getUserName(at: "/nonexistent/path/that/does/not/exist", verbose: false)) { error in
            XCTAssertTrue(error is LibGit2Error)
        }
    }

    func testGitConfigEmptyRepository() throws {
        // 创建一个新的临时目录作为空仓库（不继承testRepo的配置）
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("LibGit2SwiftTests-Empty-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // 在新目录创建空仓库
        _ = try LibGit2.createRepository(at: tempDir.path)

        XCTAssertThrowsError(try GitConfig.getUserName(at: tempDir.path, verbose: false))
        XCTAssertThrowsError(try GitConfig.getUserEmail(at: tempDir.path, verbose: false))
    }
}