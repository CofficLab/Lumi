import Foundation
@testable import LibGit2Swift
import XCTest

/// LibGit2Swift 测试基类
/// 提供测试初始化和清理的通用功能
class LibGit2SwiftTestCase: XCTestCase {
    /// 测试用的 Git 仓库
    var testRepo: TestGitRepository!

    /// 设置测试环境
    override func setUp() async throws {
        try await super.setUp()

        // 初始化 libgit2
        LibGit2.initialize()

        // 创建测试仓库
        testRepo = TestGitRepository(testName: name)
        try testRepo.create()
    }

    /// 清理测试环境
    override func tearDown() async throws {
        // 清理测试仓库
        testRepo?.cleanup()
        testRepo = nil

        // 关闭 libgit2
        LibGit2.shutdown()

        try await super.tearDown()
    }

    /// 等待异步操作完成
    func waitForAsyncOperation(_ timeout: TimeInterval = 5.0,
                               operation: @escaping () async throws -> Void) async throws {
        try await withTimeout(seconds: timeout) {
            try await operation()
        }
    }

    /// 带超时的异步操作
    private func withTimeout<T>(seconds: TimeInterval,
                               operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }

            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TimeoutError()
            }

            guard let result = try await group.next(), !Task.isCancelled else {
                throw TimeoutError()
            }

            group.cancelAll()
            return result
        }
    }

    struct TimeoutError: Error {
        let localizedDescription: String = "Operation timed out"
    }
}

/// 测试数据生成器
enum TestDataGenerator {
    /// 生成随机的文件名
    static func randomFileName() -> String {
        "file_\(UUID().uuidString.prefix(8)).txt"
    }

    /// 生成随机的提交信息
    static func randomCommitMessage() -> String {
        "Test commit \(UUID().uuidString.prefix(8))"
    }

    /// 生成随机的分支名称
    static func randomBranchName() -> String {
        "branch_\(UUID().uuidString.prefix(8))"
    }

    /// 生成随机的标签名称
    static func randomTagName() -> String {
        "tag_\(UUID().uuidString.prefix(8))"
    }

    /// 生成测试文本内容
    static func testContent() -> String {
        """
        This is a test file.
        Line 2: Some content.
        Line 3: More content.
        """
    }

    /// 生成测试用的作者信息
    static func testAuthor() -> (name: String, email: String) {
        ("Test User", "test@example.com")
    }
}
