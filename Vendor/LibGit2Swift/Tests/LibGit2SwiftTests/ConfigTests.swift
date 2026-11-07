import Foundation
@testable import LibGit2Swift
import XCTest

/// Configuration 相关功能的测试
final class ConfigTests: LibGit2SwiftTestCase {
    // MARK: - Set Config Tests

    func testSetConfig() throws {
        // 设置配置
        let key = "user.name"
        let value = "Test User"
        try LibGit2.setConfig(key: key, value: value, at: testRepo.repositoryPath, verbose: false)

        // 验证配置已设置
        let retrievedValue = try LibGit2.getConfig(key: key, at: testRepo.repositoryPath, verbose: false)
        XCTAssertEqual(retrievedValue, value, "Retrieved value should match the set value")
    }

    func testSetMultipleConfigs() throws {
        // 设置多个配置
        let configs = [
            ("user.name", "Test User"),
            ("user.email", "test@example.com"),
            ("core.editor", "vim"),
            ("merge.conflictstyle", "diff3")
        ]

        for (key, value) in configs {
            try LibGit2.setConfig(key: key, value: value, at: testRepo.repositoryPath, verbose: false)
        }

        // 验证所有配置
        for (key, value) in configs {
            let retrievedValue = try LibGit2.getConfig(key: key, at: testRepo.repositoryPath, verbose: false)
            XCTAssertEqual(retrievedValue, value, "Config '\(key)' should match")
        }
    }

    // MARK: - Get Config Tests

    func testGetConfig() throws {
        // 设置配置
        let key = "test.key"
        let value = "test value"
        try LibGit2.setConfig(key: key, value: value, at: testRepo.repositoryPath, verbose: false)

        // 获取配置
        let retrievedValue = try LibGit2.getConfig(key: key, at: testRepo.repositoryPath, verbose: false)

        XCTAssertEqual(retrievedValue, value, "Retrieved value should match")
    }

    func testGetNonExistentConfig() throws {
        // 尝试获取不存在的配置
        let nonExistentKey = "nonexistent.key"

        XCTAssertThrowsError(
            try LibGit2.getConfig(key: nonExistentKey, at: testRepo.repositoryPath, verbose: false)
        ) { error in
            XCTAssertTrue(error is LibGit2Error, "Should throw LibGit2Error for non-existent config")
        }
    }

    // MARK: - User Name and Email Tests

    func testGetUserName() throws {
        // 设置用户名
        let expectedName = "John Doe"
        try LibGit2.setConfig(key: "user.name", value: expectedName, at: testRepo.repositoryPath, verbose: false)

        // 获取用户名
        let userName = try LibGit2.getUserName(at: testRepo.repositoryPath, verbose: false)

        XCTAssertEqual(userName, expectedName, "User name should match")
    }

    func testGetUserEmail() throws {
        // 设置用户邮箱
        let expectedEmail = "john.doe@example.com"
        try LibGit2.setConfig(key: "user.email", value: expectedEmail, at: testRepo.repositoryPath, verbose: false)

        // 获取用户邮箱
        let userEmail = try LibGit2.getUserEmail(at: testRepo.repositoryPath)

        XCTAssertEqual(userEmail, expectedEmail, "User email should match")
    }

    func testSetUserName() throws {
        // 设置用户名
        let expectedName = "Jane Smith"
        try LibGit2.setUserName(name: expectedName, at: testRepo.repositoryPath)

        // 验证
        let retrievedName = try LibGit2.getUserName(at: testRepo.repositoryPath, verbose: false)

        XCTAssertEqual(retrievedName, expectedName, "User name should be set correctly")
    }

    func testSetUserEmail() throws {
        // 设置用户邮箱
        let expectedEmail = "jane.smith@example.com"
        try LibGit2.setUserEmail(email: expectedEmail, at: testRepo.repositoryPath)

        // 验证
        let retrievedEmail = try LibGit2.getUserEmail(at: testRepo.repositoryPath)

        XCTAssertEqual(retrievedEmail, expectedEmail, "User email should be set correctly")
    }

    // MARK: - Config Scope Tests

    func testLocalConfig() throws {
        // 设置本地配置
        let key = "test.local"
        let value = "local value"
        try LibGit2.setConfig(key: key, value: value, at: testRepo.repositoryPath, verbose: false)

        // 获取本地配置
        let retrievedValue = try LibGit2.getConfig(key: key, at: testRepo.repositoryPath, verbose: false)

        XCTAssertEqual(retrievedValue, value, "Local config should match")
    }

    func testGetUserNameFallback() throws {
        // 测试在本地配置未设置时回退到全局配置

        // 注意：这会修改用户的全局 Git 配置
        // 在测试环境中，我们可以测试回退逻辑

        // 设置本地用户名
        let localName = "Local User"
        try LibGit2.setUserName(name: localName, at: testRepo.repositoryPath)

        // 获取用户名应该返回本地配置
        let userName = try LibGit2.getUserName(at: testRepo.repositoryPath, verbose: false)

        XCTAssertEqual(userName, localName, "Should use local user name")
    }

    // MARK: - Special Config Keys Tests

    func testSetCoreEditor() throws {
        // 设置编辑器
        let editor = "code --wait"
        try LibGit2.setConfig(key: "core.editor", value: editor, at: testRepo.repositoryPath, verbose: false)

        let retrievedEditor = try LibGit2.getConfig(key: "core.editor", at: testRepo.repositoryPath, verbose: false)

        XCTAssertEqual(retrievedEditor, editor, "Core editor should be set")
    }

    func testSetMergeConflictStyle() throws {
        // 设置合并冲突样式
        let conflictStyle = "zdiff3"
        try LibGit2.setConfig(key: "merge.conflictstyle", value: conflictStyle,
                             at: testRepo.repositoryPath,
                             verbose: false)

        let retrievedStyle = try LibGit2.getConfig(key: "merge.conflictstyle", at: testRepo.repositoryPath, verbose: false)

        XCTAssertEqual(retrievedStyle, conflictStyle, "Merge conflict style should be set")
    }

    func testSetPushDefault() throws {
        // 设置默认推送分支
        let pushDefault = "current"
        try LibGit2.setConfig(key: "push.default", value: pushDefault,
                             at: testRepo.repositoryPath,
                             verbose: false)

        let retrievedDefault = try LibGit2.getConfig(key: "push.default", at: testRepo.repositoryPath, verbose: false)

        XCTAssertEqual(retrievedDefault, pushDefault, "Push default should be set")
    }

    // MARK: - Config with Special Characters Tests

    func testSetConfigWithSpecialCharacters() throws {
        // 设置包含特殊字符的配置值
        let key = "test.special"
        let value = "value with spaces & symbols!@#$%"

        try LibGit2.setConfig(key: key, value: value, at: testRepo.repositoryPath, verbose: false)

        let retrievedValue = try LibGit2.getConfig(key: key, at: testRepo.repositoryPath, verbose: false)

        XCTAssertEqual(retrievedValue, value, "Config with special characters should be preserved")
    }

    func testSetConfigWithDotsInKey() throws {
        // 测试多级配置键
        let key = "section.subsection.property"
        let value = "value"

        try LibGit2.setConfig(key: key, value: value, at: testRepo.repositoryPath, verbose: false)

        let retrievedValue = try LibGit2.getConfig(key: key, at: testRepo.repositoryPath, verbose: false)

        XCTAssertEqual(retrievedValue, value, "Multi-level config key should work")
    }

    // MARK: - Update Config Tests

    func testUpdateExistingConfig() throws {
        // 设置初始配置
        let key = "test.update"
        let initialValue = "initial value"
        try LibGit2.setConfig(key: key, value: initialValue, at: testRepo.repositoryPath, verbose: false)

        // 更新配置
        let updatedValue = "updated value"
        try LibGit2.setConfig(key: key, value: updatedValue, at: testRepo.repositoryPath, verbose: false)

        // 验证配置已更新
        let retrievedValue = try LibGit2.getConfig(key: key, at: testRepo.repositoryPath, verbose: false)

        XCTAssertEqual(retrievedValue, updatedValue, "Config should be updated")
        XCTAssertNotEqual(retrievedValue, initialValue, "Config should not be the initial value")
    }

    // MARK: - Error Handling Tests

    func testSetConfigWithEmptyKey() throws {
        // 尝试设置空键名的配置应该失败
        XCTAssertThrowsError(
            try LibGit2.setConfig(key: "", value: "value", at: testRepo.repositoryPath, verbose: false)
        ) { error in
            XCTAssertTrue(error is LibGit2Error, "Should throw LibGit2Error for empty key")
        }
    }

    func testSetConfigWithEmptyValue() throws {
        // 空值应该是有效的（用于删除配置）
        // 但某些键可能不允许空值
        let key = "test.empty"

        // 设置空值（这可能会删除配置）
        XCTAssertNoThrow(
            try LibGit2.setConfig(key: key, value: "", at: testRepo.repositoryPath, verbose: false)
        )

        // 验证配置已删除
        XCTAssertThrowsError(
            try LibGit2.getConfig(key: key, at: testRepo.repositoryPath, verbose: false)
        )
    }

    // MARK: - Config Persistence Tests

    func testConfigPersistsAcrossOperations() throws {
        // 设置配置
        let key = "test.persistence"
        let value = "persistent value"
        try LibGit2.setConfig(key: key, value: value, at: testRepo.repositoryPath, verbose: false)

        // 创建一个提交
        try testRepo.createFileAndCommit(
            fileName: "test.txt",
            content: "Test",
            message: "Test commit"
        )

        // 配置应该仍然存在
        let retrievedValue = try LibGit2.getConfig(key: key, at: testRepo.repositoryPath, verbose: false)

        XCTAssertEqual(retrievedValue, value, "Config should persist across operations")
    }

    // MARK: - Complex Scenarios

    func testCompleteUserConfiguration() throws {
        // 设置完整的用户配置
        let name = "Alice Johnson"
        let email = "alice.johnson@company.com"

        try LibGit2.setUserName(name: name, at: testRepo.repositoryPath)
        try LibGit2.setUserEmail(email: email, at: testRepo.repositoryPath)

        // 验证配置
        let retrievedName = try LibGit2.getUserName(at: testRepo.repositoryPath, verbose: false)
        let retrievedEmail = try LibGit2.getUserEmail(at: testRepo.repositoryPath)

        XCTAssertEqual(retrievedName, name, "User name should be correct")
        XCTAssertEqual(retrievedEmail, email, "User email should be correct")

        // 创建提交使用配置的用户信息
        try testRepo.createFileAndCommit(
            fileName: "authored.txt",
            content: "Content",
            message: "Commit by Alice",
            authorName: name,
            authorEmail: email
        )

        // 验证提交使用了正确的用户信息
        let commits = try LibGit2.getCommitList(at: testRepo.repositoryPath)
        let commit = commits.first

        XCTAssertEqual(commit?.author, name, "Commit author should match configured name")
        XCTAssertEqual(commit?.email, email, "Commit email should match configured email")
    }

    func testMultipleConfigSections() throws {
        // 在不同配置节中设置值
        let configs = [
            ("user.name", "Test User"),
            ("core.autocrlf", "input"),
            ("color.ui", "true"),
            ("format.pretty", "format:%h %s")
        ]

        for (key, value) in configs {
            try LibGit2.setConfig(key: key, value: value, at: testRepo.repositoryPath, verbose: false)
        }

        // 验证所有配置
        for (key, value) in configs {
            let retrievedValue = try LibGit2.getConfig(key: key, at: testRepo.repositoryPath, verbose: false)
            XCTAssertEqual(retrievedValue, value, "Config '\(key)' should match")
        }
    }

    func testConfigWithBranchSpecific() throws {
        // 创建初始提交
        try testRepo.createFileAndCommit(
            fileName: "initial.txt",
            content: "Initial",
            message: "Initial commit"
        )

        // 设置分支特定的配置
        let branch = "master"
        let key = "branch.\(branch).description"
        let value = "Main development branch"

        try LibGit2.setConfig(key: key, value: value, at: testRepo.repositoryPath, verbose: false)

        // 验证配置
        let retrievedValue = try LibGit2.getConfig(key: key, at: testRepo.repositoryPath, verbose: false)

        XCTAssertEqual(retrievedValue, value, "Branch-specific config should work")
    }
}
