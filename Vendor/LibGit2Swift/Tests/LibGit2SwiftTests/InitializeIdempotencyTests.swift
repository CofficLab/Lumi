import Foundation
@testable import LibGit2Swift
import XCTest

/// 测试 `LibGit2.initialize()` / `shutdown()` 的幂等性
///
/// 背景：libgit2 C 层要求 `git_libgit2_init()` / `git_libgit2_shutdown()` 配对调用；
/// 多次 init 必须匹配相同次数的 shutdown，否则会留下悬挂的资源。
/// Swift 包装层现在用引用计数 + `OSAllocatedUnfairLock` 保证：
/// 1. 第一次 initialize() 才真正调 C init，后续只递增计数
/// 2. shutdown() 把计数减到 0 时才真正调 C shutdown
/// 3. 多线程并发调用是安全的
final class InitializeIdempotencyTests: XCTestCase {

    // MARK: - 引用计数正确性

    /// 第一次 initialize 后计数应为 1
    func testFirstInitializeIncrementsCountToOne() {
        let before = LibGit2.initializationCount
        LibGit2.initialize()
        XCTAssertEqual(LibGit2.initializationCount, before + 1, "首次 initialize 后计数 +1")
    }

    /// 多次 initialize 只递增计数，不重复触发 C init
    /// （通过计数变化间接验证——如果 C init 报错，refcount 行为也会暴露问题）
    func testRepeatedInitializeIncrementsCount() {
        let before = LibGit2.initializationCount

        LibGit2.initialize()
        LibGit2.initialize()
        LibGit2.initialize()

        XCTAssertEqual(
            LibGit2.initializationCount, before + 3,
            "连续 3 次 initialize 后计数 +3（refcount 视角）"
        )
    }

    /// shutdown 递减计数；最后才会真正触发 C shutdown
    func testShutdownDecrementsCount() {
        let before = LibGit2.initializationCount

        LibGit2.initialize()
        LibGit2.initialize()
        XCTAssertEqual(LibGit2.initializationCount, before + 2)

        LibGit2.shutdown()
        XCTAssertEqual(LibGit2.initializationCount, before + 1, "shutdown 一次只减 1")

        LibGit2.shutdown()
        XCTAssertEqual(LibGit2.initializationCount, before, "配对完成后计数回到原值")
    }

    /// shutdown 不会让计数变成负数（防御性）
    func testShutdownDoesNotUnderflow() {
        // 不管当前计数多少，再调几次 shutdown 也不应崩
        LibGit2.shutdown()
        LibGit2.shutdown()
        LibGit2.shutdown()
        XCTAssertGreaterThanOrEqual(LibGit2.initializationCount, 0, "计数不能为负")
    }

    // MARK: - 初始化后 libgit2 操作可用

    /// 关键回归测试：先 initialize，再 isGitRepository，应该正确工作
    /// 这正是修复前报 "library has not been initialized" 的路径
    func testIsGitRepositoryWorksAfterInitialize() throws {
        // 找系统中一个真实的 git 仓库根目录用于测试
        let candidates = [
            "/Users/angel/Code/Coffic/Lumi",
            FileManager.default.currentDirectoryPath,
            "/tmp",
        ]
        let realRepoPath = candidates.first {
            FileManager.default.fileExists(atPath: $0 + "/.git")
        }

        guard let realRepoPath else {
            throw XCTSkip("No real git repo found for testing")
        }

        LibGit2.initialize()
        let isRepo = LibGit2.isGitRepository(at: realRepoPath)
        XCTAssertTrue(isRepo, "initialize 后 isGitRepository 应能识别真实仓库")
    }

    /// 多次 initialize 后 libgit2 操作仍然可用（不会因为重复 init 而损坏状态）
    func testIsGitRepositoryWorksAfterMultipleInitialize() {
        LibGit2.initialize()
        LibGit2.initialize()
        LibGit2.initialize()

        let isRepo = LibGit2.isGitRepository(at: FileManager.default.currentDirectoryPath)
        XCTAssertTrue(isRepo, "多次 initialize 后仍可正常识别仓库")
    }

    // MARK: - 并发安全

    /// 多线程并发 initialize：必须都成功，且计数正确
    func testConcurrentInitializeIsThreadSafe() {
        let before = LibGit2.initializationCount
        let concurrentCount = 50

        let expectation = XCTestExpectation(description: "concurrent initialize")
        expectation.expectedFulfillmentCount = concurrentCount

        let queue = DispatchQueue(label: "test.initialize", attributes: .concurrent)
        let group = DispatchGroup()

        for _ in 0..<concurrentCount {
            group.enter()
            queue.async {
                LibGit2.initialize()
                expectation.fulfill()
                group.leave()
            }
        }

        group.wait()
        wait(for: [expectation], timeout: 5.0)

        XCTAssertEqual(
            LibGit2.initializationCount, before + concurrentCount,
            "50 次并发 initialize 后计数应严格 +50（无丢失、无重复）"
        )

        // 平衡：把计数减回去，避免污染其他测试
        for _ in 0..<concurrentCount {
            LibGit2.shutdown()
        }
    }

    /// 混合：并发 initialize 和 shutdown，最终计数应符合 net effect
    func testConcurrentInitializeAndShutdown() {
        let before = LibGit2.initializationCount
        let iterations = 100

        let queue = DispatchQueue(label: "test.mixed", attributes: .concurrent)
        let group = DispatchGroup()

        for i in 0..<iterations {
            group.enter()
            queue.async {
                if i % 2 == 0 {
                    LibGit2.initialize()
                } else {
                    LibGit2.shutdown()
                }
                group.leave()
            }
        }

        group.wait()

        // 不管怎么交错，最终计数应 >= 0 且 <= before + initCalls
        XCTAssertGreaterThanOrEqual(
            LibGit2.initializationCount, 0,
            "并发混合调用后计数不能为负"
        )
        XCTAssertLessThanOrEqual(
            LibGit2.initializationCount, before + iterations,
            "计数不能超过 (initial + init-only calls)"
        )

        // 平衡
        while LibGit2.initializationCount > before {
            LibGit2.shutdown()
        }
    }
}
