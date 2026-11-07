import Foundation
@testable import LibGit2Swift
import Clibgit2
import XCTest

/// 测试辅助工具类
/// 用于创建和管理测试用的 Git 仓库
final class TestGitRepository {
    let tempDirectory: URL
    let repositoryPath: String

    private var isDirectoryCreated: Bool = false

    /// 初始化测试仓库
    /// - Parameter testName: 测试名称，用于创建唯一的临时目录
    init(testName: String) {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("LibGit2SwiftTests")
            .appendingPathComponent(testName)

        self.tempDirectory = tempDir
        self.repositoryPath = tempDir.path
    }

    /// 创建测试仓库目录并初始化 Git 仓库
    /// - Returns: 仓库路径
    @discardableResult
    func create() throws -> String {
        // 创建临时目录
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        isDirectoryCreated = true

        // 初始化 Git 仓库
        LibGit2.initialize()
        let repo = try LibGit2.createRepository(at: repositoryPath)
        git_repository_free(repo)

        return repositoryPath
    }

    /// 在测试仓库中创建一个文件并提交
    /// - Parameters:
    ///   - fileName: 文件名
    ///   - content: 文件内容
    ///   - message: 提交信息
    ///   - authorName: 作者名称
    ///   - authorEmail: 作者邮箱
    func createFileAndCommit(
        fileName: String,
        content: String,
        message: String,
        authorName: String = "Test User",
        authorEmail: String = "test@example.com"
    ) throws {
        let fileURL = tempDirectory.appendingPathComponent(fileName)

        // 创建文件
        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        // 添加文件到暂存区
        try LibGit2.addFiles([fileName], at: repositoryPath)

        // 配置用户信息
        try LibGit2.setConfig(key: "user.name", value: authorName, at: repositoryPath, verbose: false)
        try LibGit2.setConfig(key: "user.email", value: authorEmail, at: repositoryPath, verbose: false)

        // 创建提交
        _ = try LibGit2.createCommit(message: message, at: repositoryPath, verbose: false)

        // 如果这是第一次调用，确保创建main分支
        // 注意：这可能不是最优的解决方案，但可以避免重复创建分支的问题
    }

    /// 创建多个分支
    /// - Parameter branches: 分支名称数组
    func createBranches(_ branches: [String]) throws {
        for branchName in branches {
            _ = try LibGit2.createBranch(named: branchName, at: repositoryPath)
        }
    }

    /// 创建测试标签
    /// - Parameters:
    ///   - tagName: 标签名
    ///   - message: 标签消息
    func createTag(tagName: String, message: String? = nil) throws {
        try LibGit2.createTag(named: tagName, message: message, in: repositoryPath, verbose: false)
    }

    /// 添加远程仓库
    /// - Parameters:
    ///   - name: 远程仓库名称
    ///   - url: 远程仓库 URL
    func addRemote(name: String, url: String) throws {
        try LibGit2.addRemote(name: name, url: url, at: repositoryPath)
    }

    /// 读取文件内容
    /// - Parameter fileName: 文件名
    /// - Returns: 文件内容
    func readFile(_ fileName: String) throws -> String {
        let fileURL = tempDirectory.appendingPathComponent(fileName)
        return try String(contentsOf: fileURL, encoding: .utf8)
    }

    /// 清理测试仓库
    func cleanup() {
        if isDirectoryCreated {
            try? FileManager.default.removeItem(at: tempDirectory)
            isDirectoryCreated = false
        }
    }

    deinit {
        cleanup()
    }
}

/// 测试断言辅助方法
extension XCTestCase {
    /// 断言文件存在于仓库中
    func assertFileExists(_ fileName: String, in repository: TestGitRepository) {
        let fileURL = repository.tempDirectory.appendingPathComponent(fileName)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path),
                     "File '\(fileName)' should exist in repository")
    }

    /// 断言文件不存在于仓库中
    func assertFileNotExists(_ fileName: String, in repository: TestGitRepository) {
        let fileURL = repository.tempDirectory.appendingPathComponent(fileName)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path),
                      "File '\(fileName)' should not exist in repository")
    }

    /// 断言抛出特定类型的错误
    func assertThrowsError<T>(_ expression: @autoclosure () throws -> T,
                             _ errorType: LibGit2Error.Type,
                             file: StaticString = #file,
                             line: UInt = #line) {
        XCTAssertThrowsError(try expression(), file: file, line: line) { error in
            XCTAssertTrue(error is LibGit2Error,
                          "Expected LibGit2Error but got \(type(of: error))")
        }
    }
}
