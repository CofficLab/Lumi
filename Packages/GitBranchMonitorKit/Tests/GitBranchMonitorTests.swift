import Testing
import Foundation
@testable import GitBranchMonitorKit

// MARK: - Thread-safe helpers for @Sendable closures

/// 线程安全的计数器，用于在 @Sendable 回调中统计调用次数
final class LockedCounter: @unchecked Sendable {
    private var _value = 0
    private let lock = NSLock()

    func increment() {
        lock.lock()
        _value += 1
        lock.unlock()
    }

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return _value
    }
}

/// 简单的异步期望辅助，用于测试回调是否触发及触发值
final class Expectation<T: Sendable>: @unchecked Sendable {
    private var _value: T?
    private let lock = NSLock()

    func fulfill(with value: T) {
        lock.lock()
        _value = value
        lock.unlock()
    }

    var value: T? {
        lock.lock()
        defer { lock.unlock() }
        return _value
    }
}

// MARK: - Tests

@MainActor
@Suite("GitBranchMonitor Tests")
struct GitBranchMonitorTests {

    // MARK: - Helpers

    /// 创建临时目录并初始化 .git/HEAD 文件
    private func createTempRepo(headContent: String) -> URL {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("GitBranchMonitorTest-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)

        let gitDir = tmpDir.appendingPathComponent(".git")
        try? FileManager.default.createDirectory(at: gitDir, withIntermediateDirectories: true)

        let headPath = gitDir.appendingPathComponent("HEAD")
        try? headContent.write(to: headPath, atomically: true, encoding: .utf8)

        return tmpDir
    }

    /// 清理临时目录
    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - parseHeadContent (pure function, no file I/O)

    @Test("解析标准分支引用")
    func parseHeadContent_branchReference() {
        #expect(GitBranchMonitor.parseHeadContent("ref: refs/heads/main\n") == "main")
        #expect(GitBranchMonitor.parseHeadContent("ref: refs/heads/feature/login") == "feature/login")
        #expect(GitBranchMonitor.parseHeadContent("ref: refs/heads/fix/issue-123") == "fix/issue-123")
        #expect(GitBranchMonitor.parseHeadContent("ref: refs/heads/develop") == "develop")
    }

    @Test("解析分离头指针（40 位 commit hash）")
    func parseHeadContent_detachedHead() {
        let hash = "abc1234567890abcdef1234567890abcdef12345678"
        #expect(GitBranchMonitor.parseHeadContent(hash) == nil)
    }

    @Test("解析空内容返回 nil")
    func parseHeadContent_empty() {
        #expect(GitBranchMonitor.parseHeadContent("") == nil)
    }

    @Test("解析 ref: refs/heads/ 后为空返回 nil")
    func parseHeadContent_emptyBranch() {
        #expect(GitBranchMonitor.parseHeadContent("ref: refs/heads/") == nil)
    }

    @Test("解析无效内容返回 nil")
    func parseHeadContent_invalid() {
        #expect(GitBranchMonitor.parseHeadContent("some random text") == nil)
        #expect(GitBranchMonitor.parseHeadContent("not a valid HEAD") == nil)
    }

    @Test("解析带前后空白的分支名")
    func parseHeadContent_whitespace() {
        #expect(GitBranchMonitor.parseHeadContent("  ref: refs/heads/main  \n") == "main")
    }

    @Test("解析分支名包含特殊字符")
    func parseHeadContent_specialChars() {
        #expect(GitBranchMonitor.parseHeadContent("ref: refs/heads/release/1.0.0") == "release/1.0.0")
        #expect(GitBranchMonitor.parseHeadContent("ref: refs/heads/fix/issue_42") == "fix/issue_42")
    }

    // MARK: - parseHeadFile (reads from disk)

    @Test("从实际文件解析 HEAD")
    func parseHeadFile_realFile() throws {
        let repoURL = createTempRepo(headContent: "ref: refs/heads/main\n")
        defer { cleanup(repoURL) }

        let headPath = GitBranchMonitor.headPath(for: repoURL.path)
        #expect(GitBranchMonitor.parseHeadFile(at: headPath) == "main")
    }

    @Test("解析不存在的文件返回 nil")
    func parseHeadFile_nonexistent() {
        let path = "/tmp/nonexistent-\(UUID().uuidString)/.git/HEAD"
        #expect(GitBranchMonitor.parseHeadFile(at: path) == nil)
    }

    @Test("文件内容变化后重新解析")
    func parseHeadFile_afterChange() throws {
        let repoURL = createTempRepo(headContent: "ref: refs/heads/main\n")
        defer { cleanup(repoURL) }

        let headPath = GitBranchMonitor.headPath(for: repoURL.path)
        #expect(GitBranchMonitor.parseHeadFile(at: headPath) == "main")

        // 修改文件
        try "ref: refs/heads/develop\n".write(
            to: repoURL.appendingPathComponent(".git/HEAD"),
            atomically: true, encoding: .utf8
        )
        #expect(GitBranchMonitor.parseHeadFile(at: headPath) == "develop")
    }

    // MARK: - headPath

    @Test("构造 .git/HEAD 路径")
    func headPath() {
        #expect(GitBranchMonitor.headPath(for: "/Users/dev/project") == "/Users/dev/project/.git/HEAD")
        #expect(GitBranchMonitor.headPath(for: "/tmp") == "/tmp/.git/HEAD")
        #expect(GitBranchMonitor.headPath(for: "") == "/.git/HEAD")
    }

    // MARK: - startMonitoring / stopMonitoring (integration with DispatchSource)

    @Test("监听非 Git 项目不产生错误且不添加监听")
    func startMonitoring_nonGitRepo() {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("NonGit-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let monitor = GitBranchMonitor()
        monitor.startMonitoring(projectPath: tmpDir.path)

        #expect(monitor.monitoredPaths.isEmpty)
    }

    @Test("stopMonitoring 不存在的路径不做任何操作")
    func stopMonitoring_nonexistent() {
        let monitor = GitBranchMonitor()
        monitor.stopMonitoring(projectPath: "/nonexistent/path")
        #expect(monitor.monitoredPaths.isEmpty)
    }

    // MARK: - handleFileChange (core logic, tested without DispatchSource)

    @Test("handleFileChange 检测到分支变化时触发回调")
    func handleFileChange_firesCallbackOnBranchChange() async throws {
        let repoURL = createTempRepo(headContent: "ref: refs/heads/main\n")
        defer { cleanup(repoURL) }

        let monitor = GitBranchMonitor()
        monitor.debounceDelay = 0.05

        // 手动设置初始状态（模拟 startMonitoring 的效果，但不创建 DispatchSource）
        let headPath = GitBranchMonitor.headPath(for: repoURL.path)
        let initialBranch = GitBranchMonitor.parseHeadFile(at: headPath)
        monitor.monitors[repoURL.path] = GitBranchMonitor.MonitorState(
            fileDescriptor: -1,
            dispatchSource: nil,
            lastBranch: initialBranch,
            lastUpdateTime: Date()
        )

        let expectation = Expectation<String?>()
        monitor.onBranchChange { _, branch in
            expectation.fulfill(with: branch)
        }

        #expect(monitor.currentBranch(for: repoURL.path) == "main")

        // 模拟分支切换
        try "ref: refs/heads/develop\n".write(
            to: repoURL.appendingPathComponent(".git/HEAD"),
            atomically: true, encoding: .utf8
        )
        monitor.handleFileChange(projectPath: repoURL.path)

        try await Task.sleep(for: .milliseconds(200))

        #expect(expectation.value == "develop")
    }

    @Test("handleFileChange 分支未变化时不触发回调")
    func handleFileChange_noCallbackWhenUnchanged() async throws {
        let repoURL = createTempRepo(headContent: "ref: refs/heads/main\n")
        defer { cleanup(repoURL) }

        let monitor = GitBranchMonitor()
        monitor.debounceDelay = 0.05

        let headPath = GitBranchMonitor.headPath(for: repoURL.path)
        let initialBranch = GitBranchMonitor.parseHeadFile(at: headPath)
        monitor.monitors[repoURL.path] = GitBranchMonitor.MonitorState(
            fileDescriptor: -1,
            dispatchSource: nil,
            lastBranch: initialBranch,
            lastUpdateTime: Date()
        )

        let callCount = LockedCounter()
        monitor.onBranchChange { _, _ in callCount.increment() }

        // 不修改文件，直接触发
        monitor.handleFileChange(projectPath: repoURL.path)

        try await Task.sleep(for: .milliseconds(200))

        #expect(callCount.value == 0)
    }

    @Test("多个回调都被触发")
    func multipleCallbacks() async throws {
        let repoURL = createTempRepo(headContent: "ref: refs/heads/main\n")
        defer { cleanup(repoURL) }

        let monitor = GitBranchMonitor()
        monitor.debounceDelay = 0.05

        let headPath = GitBranchMonitor.headPath(for: repoURL.path)
        let initialBranch = GitBranchMonitor.parseHeadFile(at: headPath)
        monitor.monitors[repoURL.path] = GitBranchMonitor.MonitorState(
            fileDescriptor: -1,
            dispatchSource: nil,
            lastBranch: initialBranch,
            lastUpdateTime: Date()
        )

        let counter1 = LockedCounter()
        let counter2 = LockedCounter()
        monitor.onBranchChange { _, _ in counter1.increment() }
        monitor.onBranchChange { _, _ in counter2.increment() }

        try "ref: refs/heads/develop\n".write(
            to: repoURL.appendingPathComponent(".git/HEAD"),
            atomically: true, encoding: .utf8
        )
        monitor.handleFileChange(projectPath: repoURL.path)

        try await Task.sleep(for: .milliseconds(200))

        #expect(counter1.value == 1)
        #expect(counter2.value == 1)
    }

    // MARK: - Debounce

    @Test("防抖：快速连续触发只产生一次回调")
    func debounce_coalescesRapidChanges() async throws {
        let repoURL = createTempRepo(headContent: "ref: refs/heads/main\n")
        defer { cleanup(repoURL) }

        let monitor = GitBranchMonitor()
        monitor.debounceDelay = 0.1

        let headPath = GitBranchMonitor.headPath(for: repoURL.path)
        let initialBranch = GitBranchMonitor.parseHeadFile(at: headPath)
        monitor.monitors[repoURL.path] = GitBranchMonitor.MonitorState(
            fileDescriptor: -1,
            dispatchSource: nil,
            lastBranch: initialBranch,
            lastUpdateTime: Date()
        )

        let callCount = LockedCounter()
        monitor.onBranchChange { _, _ in callCount.increment() }

        let headFile = repoURL.appendingPathComponent(".git/HEAD")

        // 快速连续触发 3 次
        for i in 0..<3 {
            try "ref: refs/heads/branch-\(i)\n".write(to: headFile, atomically: true, encoding: .utf8)
            monitor.handleFileChange(projectPath: repoURL.path)
        }

        try await Task.sleep(for: .milliseconds(400))

        // 只应有 1 次回调（防抖合并了快速连续的变化）
        #expect(callCount.value == 1)
    }

    // MARK: - currentBranch / monitoredPaths

    @Test("currentBranch 对未监听的路径返回 nil")
    func currentBranch_unmonitored() {
        let monitor = GitBranchMonitor()
        #expect(monitor.currentBranch(for: "/some/path") == nil)
    }

    @Test("monitoredPaths 初始为空")
    func monitoredPaths_initiallyEmpty() {
        let monitor = GitBranchMonitor()
        #expect(monitor.monitoredPaths.isEmpty)
    }

    // MARK: - stopAll

    @Test("stopAll 清除所有状态和回调")
    func stopAll_clearsEverything() {
        let monitor = GitBranchMonitor()
        monitor.onBranchChange { _, _ in }
        monitor.onBranchChange { _, _ in }

        monitor.stopAll()

        #expect(monitor.monitoredPaths.isEmpty)
        #expect(monitor.callbacks.isEmpty)
    }
}
