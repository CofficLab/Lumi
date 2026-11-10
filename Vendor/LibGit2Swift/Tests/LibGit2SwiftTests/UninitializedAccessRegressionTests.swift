import XCTest
@testable import LibGit2Swift

/// 回归测试：未显式调用 `LibGit2.initialize()` 时的安全性。
///
/// ## 背景（生产崩溃根因）
///
/// 若进程从未调用 `git_libgit2_init()`，libgit2 `errors.c` 的 `_tls_key` 为 0，
/// 错误处理路径会把 TSD 0 号槽（macOS 保留给 PAC 签名的 `pthread_self` 值）
/// 当作自己的 TLS 存储读写，导致宿主进程随机 `EXC_BREAKPOINT`
/// （`pthread_self` PAC 校验失败，`brk #0xc473`，TSD 槽内残留 `&git_str__oom`）。
///
/// 修复：`LibGit2.serialized` 入口通过 `static let` 惰性完成 C 层初始化。
///
/// 本套件命名以 `AAA` 开头以尽量先于其他套件运行（其他套件会显式
/// 初始化 C 层，之后本测试就无法再验证"未初始化"路径了）。即便不是在
/// 最前运行，这些用例也必须全部通过。
final class AAAUninitializedAccessRegressionTests: XCTestCase {

    /// 单线程密集触发 libgit2 错误路径（不存在的仓库）。
    /// 若 C 层未初始化，首次错误调用就会污染当前线程 TSD 并导致进程崩溃。
    func testErrorPathsOnCurrentThread() {
        for i in 0..<200 {
            XCTAssertThrowsError(try LibGit2.getCurrentBranch(at: "/nonexistent-repo-\(i)"))
            XCTAssertFalse(LibGit2.isGitRepository(at: "/nonexistent-repo-\(i)"))
        }
    }

    /// 多线程并发触发错误路径：每个 worker 线程都会经过 libgit2 错误处理。
    /// 修复前，任一线程的 TSD 0 号槽被写坏后，后续的 pthread_self 会 trap。
    func testErrorPathsOnManyThreads() {
        let group = DispatchGroup()
        for worker in 0..<16 {
            group.enter()
            DispatchQueue.global().async {
                for i in 0..<50 {
                    _ = try? LibGit2.getCurrentBranch(at: "/nonexistent-\(worker)-\(i)")
                    _ = try? LibGit2.getDiffFileList(at: "/nonexistent-\(worker)-\(i)")
                }
                group.leave()
            }
        }
        XCTAssertEqual(group.wait(timeout: .now() + 60), .success)
    }

    /// 正常路径 + 错误路径混合，模拟真实使用。
    func testMixedSuccessAndErrorPaths() throws {
        let repo = NSTemporaryDirectory() + "libgit2-uninit-regression-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: repo, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: repo) }

        XCTAssertFalse(LibGit2.isGitRepository(at: repo))
        _ = try LibGit2.createRepository(at: repo)
        XCTAssertTrue(LibGit2.isGitRepository(at: repo))
        // 空仓库触发各类软错误（无 HEAD、无分支等）
        _ = try? LibGit2.getCurrentBranch(at: repo)
        _ = try? LibGit2.getCommitList(at: repo, limit: 10)
        _ = try? LibGit2.getDiffFileList(at: repo, staged: false)
    }
}
