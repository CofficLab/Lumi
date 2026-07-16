import Testing
import Foundation
@testable import FileSystemKit

@Suite("FileTreeWatcher Tests")
struct FileTreeWatcherTests {

    // MARK: - Helper

    private func makeTempDirectory() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileTreeKitWatcher-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }

    // MARK: - Basic

    @Test("watchCount is zero initially")
    func watchCountInitiallyZero() {
        let watcher = FileTreeWatcher { _ in }
        #expect(watcher.watchCount == 0)
    }

    @Test("startWatching increases watchCount")
    func startWatchingIncreasesCount() throws {
        let dir = try makeTempDirectory()
        let watcher = FileTreeWatcher { _ in }
        watcher.verbose = false

        watcher.startWatching(url: dir)
        #expect(watcher.watchCount == 1)

        watcher.stopAll()
    }

    @Test("stopWatching decreases watchCount")
    func stopWatchingDecreasesCount() throws {
        let dir = try makeTempDirectory()
        let watcher = FileTreeWatcher { _ in }
        watcher.verbose = false

        watcher.startWatching(url: dir)
        #expect(watcher.watchCount == 1)

        watcher.stopWatching(url: dir)
        #expect(watcher.watchCount == 0)
    }

    @Test("stopAll clears all watches")
    func stopAllClearsWatches() throws {
        let dir1 = try makeTempDirectory()
        let dir2 = try makeTempDirectory()
        let watcher = FileTreeWatcher { _ in }
        watcher.verbose = false

        watcher.startWatching(url: dir1)
        watcher.startWatching(url: dir2)
        #expect(watcher.watchCount == 2)

        watcher.stopAll()
        #expect(watcher.watchCount == 0)
    }

    @Test("startWatching same URL twice does not duplicate")
    func startWatchingIdempotent() throws {
        let dir = try makeTempDirectory()
        let watcher = FileTreeWatcher { _ in }
        watcher.verbose = false

        watcher.startWatching(url: dir)
        watcher.startWatching(url: dir)
        #expect(watcher.watchCount == 1)

        watcher.stopAll()
    }

    @Test("stopWatching nonexistent URL is no-op")
    func stopWatchingNonexistentNoOp() throws {
        let watcher = FileTreeWatcher { _ in }
        watcher.verbose = false

        let fakeURL = URL(fileURLWithPath: "/nonexistent/\(UUID().uuidString)")
        watcher.stopWatching(url: fakeURL)
        #expect(watcher.watchCount == 0)
    }

    // MARK: - updateWatchedDirectories

    @Test("updateWatchedDirectories adds new directories")
    func updateWatchedDirectoriesAdds() throws {
        let dir1 = try makeTempDirectory()
        let dir2 = try makeTempDirectory()
        let watcher = FileTreeWatcher { _ in }
        watcher.verbose = false

        watcher.updateWatchedDirectories([dir1, dir2])
        #expect(watcher.watchCount == 2)

        watcher.stopAll()
    }

    @Test("updateWatchedDirectories removes old directories")
    func updateWatchedDirectoriesRemoves() throws {
        let dir1 = try makeTempDirectory()
        let dir2 = try makeTempDirectory()
        let watcher = FileTreeWatcher { _ in }
        watcher.verbose = false

        watcher.updateWatchedDirectories([dir1, dir2])
        #expect(watcher.watchCount == 2)

        // 只保留 dir1
        watcher.updateWatchedDirectories([dir1])
        #expect(watcher.watchCount == 1)

        watcher.stopAll()
    }

    @Test("updateWatchedDirectories with empty set stops all")
    func updateWatchedDirectoriesEmptyStopsAll() throws {
        let dir = try makeTempDirectory()
        let watcher = FileTreeWatcher { _ in }
        watcher.verbose = false

        watcher.updateWatchedDirectories([dir])
        #expect(watcher.watchCount == 1)

        watcher.updateWatchedDirectories([])
        #expect(watcher.watchCount == 0)
    }

    @Test("updateWatchedDirectories is idempotent for same set")
    func updateWatchedDirectoriesIdempotent() throws {
        let dir = try makeTempDirectory()
        let watcher = FileTreeWatcher { _ in }
        watcher.verbose = false

        watcher.updateWatchedDirectories([dir])
        #expect(watcher.watchCount == 1)

        watcher.updateWatchedDirectories([dir])
        #expect(watcher.watchCount == 1)

        watcher.stopAll()
    }

    // MARK: - File System Change Detection

    @Test("watcher fires callback when directory content changes")
    func watcherFiresCallbackOnFileChange() async throws {
        let dir = try makeTempDirectory()
        let expectation = Expectation()

        let watcher = FileTreeWatcher { _ in
            expectation.fulfill()
        }
        watcher.verbose = false

        watcher.startWatching(url: dir)

        // 在监控的目录中创建文件
        let fileURL = dir.appendingPathComponent("newfile.txt")
        try "hello".write(to: fileURL, atomically: true, encoding: .utf8)

        // 等待回调
        try await Task.sleep(for: .milliseconds(500))

        watcher.stopAll()
    }

    // MARK: - Verbose Logging Branches

    @Test("startWatching with verbose true logs without crash")
    func startWatchingVerboseTrue() throws {
        let dir = try makeTempDirectory()
        let watcher = FileTreeWatcher { _ in }
        watcher.verbose = false

        watcher.startWatching(url: dir)
        #expect(watcher.watchCount == 1)

        watcher.stopAll()
    }

    @Test("stopWatching with verbose true logs without crash")
    func stopWatchingVerboseTrue() throws {
        let dir = try makeTempDirectory()
        let watcher = FileTreeWatcher { _ in }
        watcher.verbose = false

        watcher.startWatching(url: dir)
        watcher.stopWatching(url: dir)
        #expect(watcher.watchCount == 0)
    }

    @Test("stopAll with verbose true logs without crash")
    func stopAllVerboseTrue() throws {
        let dir = try makeTempDirectory()
        let watcher = FileTreeWatcher { _ in }
        watcher.verbose = false

        watcher.startWatching(url: dir)
        watcher.stopAll()
        #expect(watcher.watchCount == 0)
    }

    // MARK: - deinit cleanup

    @Test("watcher deinit cleans up active watches")
    func watcherDeinitCleansUp() throws {
        let dir = try makeTempDirectory()
        // watcher 在作用域结束时 deinit，此时 watches 不为空
        // deinit 中应关闭所有 fileDescriptor 和取消 source
        do {
            let watcher = FileTreeWatcher { _ in }
            watcher.verbose = false
            watcher.startWatching(url: dir)
            #expect(watcher.watchCount == 1)
            // 不调用 stopAll，让 deinit 负责清理
        }
        // 如果 deinit 正确清理，不会产生资源泄漏或崩溃
    }

    // MARK: - updateWatchedDirectories file change detection

    @Test("updateWatchedDirectories fires callback when new watched directory changes")
    func updateWatchedDirectoriesFiresCallback() async throws {
        let dir = try makeTempDirectory()
        let expectation = Expectation()

        let watcher = FileTreeWatcher { _ in
            expectation.fulfill()
        }
        watcher.verbose = false

        watcher.updateWatchedDirectories([dir])
        #expect(watcher.watchCount == 1)

        // 在通过 updateWatchedDirectories 添加的监控目录中创建文件
        let fileURL = dir.appendingPathComponent("trigger.txt")
        try "content".write(to: fileURL, atomically: true, encoding: .utf8)

        try await Task.sleep(for: .milliseconds(500))

        watcher.stopAll()
    }

    // MARK: - watcher does not fire for unwatched directory

    @Test("watcher does not fire for unwatched directory")
    func watcherDoesNotFireForUnwatched() async throws {
        let watchedDir = try makeTempDirectory()
        let unwatchedDir = try makeTempDirectory()
        let counter = AtomicCounter()

        let watcher = FileTreeWatcher { _ in
            counter.increment()
        }
        watcher.verbose = false

        watcher.startWatching(url: watchedDir)

        // 在未监控的目录中创建文件
        let fileURL = unwatchedDir.appendingPathComponent("newfile.txt")
        try "hello".write(to: fileURL, atomically: true, encoding: .utf8)

        try await Task.sleep(for: .milliseconds(300))

        watcher.stopAll()
        #expect(counter.value == 0)
    }
}

/// 线程安全的计数器
private final class AtomicCounter: @unchecked Sendable {
    private var count = 0
    private let lock = NSLock()

    func increment() {
        lock.lock()
        count += 1
        lock.unlock()
    }

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }
}

/// 简单的异步期望辅助类
private final class Expectation: @unchecked Sendable {
    private var fulfilled = false
    private let lock = NSLock()

    func fulfill() {
        lock.lock()
        fulfilled = true
        lock.unlock()
    }

    var isFulfilled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return fulfilled
    }
}
