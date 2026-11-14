import KitDownload
import Testing
import Foundation

/// 门控 HTTP 客户端：每次 download 进入即登记并挂起，直到测试按 URL 显式放行。
///
/// 记录进入次数与「同时停留在 download 内」的峰值并发，用于断言 DownloadManager
/// 的 `maxConcurrentDownloads` 真正限制了并发（#484）。续体不响应 Task 取消，
/// 测试据此精确控制放行时序，把并发竞态变成确定性回归。
private final class ConcurrencyGatedHTTPClient: HTTPClient, @unchecked Sendable {
    struct GateTimeout: Error {}

    private let lock = NSLock()
    private var started: Set<URL> = []
    private var released: Set<URL> = []
    private var gates: [URL: CheckedContinuation<Void, Never>] = [:]
    private var entryCount = 0
    private var activeCount = 0
    private var maxActive = 0
    private let cancelOnRelease: Set<URL>
    private let failOnRelease: Set<URL>

    init(cancelOnRelease: Set<URL> = [], failOnRelease: Set<URL> = []) {
        self.cancelOnRelease = cancelOnRelease
        self.failOnRelease = failOnRelease
    }

    var entries: Int { lock.lock(); defer { lock.unlock() }; return entryCount }
    var active: Int { lock.lock(); defer { lock.unlock() }; return activeCount }
    var peakConcurrency: Int { lock.lock(); defer { lock.unlock() }; return maxActive }

    func waitUntilStarted(_ url: URL, timeout: TimeInterval = 2) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if hasStarted(url) { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        throw GateTimeout()
    }

    private func hasStarted(_ url: URL) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return started.contains(url)
    }

    func release(_ url: URL) {
        lock.lock()
        released.insert(url)
        let gate = gates.removeValue(forKey: url)
        lock.unlock()
        gate?.resume()
    }

    private func markEntered(_ url: URL) {
        lock.lock()
        started.insert(url)
        entryCount += 1
        activeCount += 1
        maxActive = max(maxActive, activeCount)
        lock.unlock()
    }

    private func markExited() {
        lock.lock()
        activeCount -= 1
        lock.unlock()
    }

    private func awaitRelease(_ url: URL) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            lock.lock()
            if released.contains(url) {
                lock.unlock()
                continuation.resume()
            } else {
                gates[url] = continuation
                lock.unlock()
            }
        }
    }

    func download(
        from url: URL,
        to destination: URL,
        existingBytes: Int64,
        maxBytesPerSecond: Int?,
        progressHandler: @Sendable @escaping (Int64, Int64?) -> Void,
        onCancelled: @Sendable @escaping (Data?) -> Void
    ) async throws -> Int64? {
        try await download(
            from: url, to: destination, existingBytes: existingBytes,
            maxBytesPerSecond: maxBytesPerSecond, headers: [:],
            progressHandler: progressHandler, onCancelled: onCancelled
        )
    }

    func download(
        from url: URL,
        to destination: URL,
        existingBytes: Int64,
        maxBytesPerSecond: Int?,
        headers: [String: String],
        progressHandler: @Sendable @escaping (Int64, Int64?) -> Void,
        onCancelled: @Sendable @escaping (Data?) -> Void
    ) async throws -> Int64? {
        markEntered(url)
        await awaitRelease(url)
        markExited()
        if cancelOnRelease.contains(url) { throw CancellationError() }
        if failOnRelease.contains(url) { throw URLError(.badServerResponse) }
        let data = Data("mock content".utf8)
        try data.write(to: destination)
        return Int64(data.count)
    }
}

@Suite("DownloadManager 并发上限回归（#484）")
struct DownloadConcurrencyLimitTests {

    private func withTempDir(_ body: (URL) async throws -> Void) async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("DownloadConcurrencyLimitTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        try await body(tempDir)
    }

    @Test("maxConcurrentDownloads 限制并发：名额耗尽时后续下载不得进入 HTTPClient")
    func maxConcurrentDownloadsLimitIsEnforced() async throws {
        try await withTempDir { tempDir in
            let url1 = URL(string: "https://example.com/1")!
            let url2 = URL(string: "https://example.com/2")!
            let mock = ConcurrencyGatedHTTPClient()
            let manager = DownloadManager(
                configuration: .init(downloadDirectory: tempDir, maxConcurrentDownloads: 1),
                httpClient: mock
            )

            // 先让第一个下载进入并占满唯一名额，再启动第二个，确保时序确定。
            let t1 = Task { try await manager.download(
                DownloadTask(id: "1", url: url1, destination: tempDir.appendingPathComponent("1.bin"))
            ) }
            try await mock.waitUntilStarted(url1)

            let t2 = Task { try await manager.download(
                DownloadTask(id: "2", url: url2, destination: tempDir.appendingPathComponent("2.bin"))
            ) }
            try await Task.sleep(for: .milliseconds(50))
            #expect(mock.entries == 1, "名额已满，第二个下载不得进入 HTTPClient")
            #expect(mock.active == 1)

            // 放行第一个 → 第二个才获得名额进入。
            mock.release(url1)
            try await mock.waitUntilStarted(url2)
            #expect(mock.entries == 2)
            mock.release(url2)

            _ = try await t1.value
            _ = try await t2.value
            #expect(mock.peakConcurrency == 1, "活跃并发不得超过 maxConcurrentDownloads=1")
        }
    }

    @Test("默认并发上限 3：四个下载时只有三个进入 HTTPClient，第四个排队")
    func defaultLimitAllowsThreeConcurrentButNotFour() async throws {
        try await withTempDir { tempDir in
            let urls = (1...4).map { URL(string: "https://example.com/\($0)")! }
            let mock = ConcurrencyGatedHTTPClient()
            let manager = DownloadManager(
                configuration: .init(downloadDirectory: tempDir),
                httpClient: mock
            )

            // 依次启动前三个并确认进入，占满默认 3 个名额。
            var tasks: [Task<URL, Error>] = []
            for i in 0..<3 {
                let url = urls[i]
                let t = Task { try await manager.download(
                    DownloadTask(id: "\(i)", url: url, destination: tempDir.appendingPathComponent("\(i).bin"))
                ) }
                tasks.append(t)
                try await mock.waitUntilStarted(url)
            }

            // 第四个：名额已满，不得进入。
            let t4 = Task { try await manager.download(
                DownloadTask(id: "3", url: urls[3], destination: tempDir.appendingPathComponent("3.bin"))
            ) }
            tasks.append(t4)
            try await Task.sleep(for: .milliseconds(50))
            #expect(mock.entries == 3, "默认上限 3，第四个下载不得进入 HTTPClient")
            #expect(mock.active == 3)

            // 放行一个 → 第四个补位进入，峰值仍为 3。
            mock.release(urls[0])
            try await mock.waitUntilStarted(urls[3])
            #expect(mock.entries == 4)
            #expect(mock.peakConcurrency == 3)

            for url in urls { mock.release(url) }
            for t in tasks { _ = try await t.value }
            #expect(mock.peakConcurrency == 3, "活跃并发不得超过默认 maxConcurrentDownloads=3")
        }
    }

    @Test("下载失败必须归还名额：排队的后续下载得以进入并完成")
    func failedDownloadReleasesSlotForQueuedDownload() async throws {
        try await withTempDir { tempDir in
            let url1 = URL(string: "https://example.com/fail")!
            let url2 = URL(string: "https://example.com/ok")!
            let mock = ConcurrencyGatedHTTPClient(failOnRelease: [url1])
            let manager = DownloadManager(
                configuration: .init(downloadDirectory: tempDir, maxConcurrentDownloads: 1),
                httpClient: mock
            )

            let t1 = Task { try await manager.download(
                DownloadTask(id: "f", url: url1, destination: tempDir.appendingPathComponent("f.bin"))
            ) }
            try await mock.waitUntilStarted(url1)

            let t2 = Task { try await manager.download(
                DownloadTask(id: "o", url: url2, destination: tempDir.appendingPathComponent("o.bin"))
            ) }
            try await Task.sleep(for: .milliseconds(50))
            #expect(mock.entries == 1, "名额已满，第二个下载不得进入 HTTPClient")

            // 放行第一个 → 它失败 → 必须归还名额让第二个进入。
            mock.release(url1)
            try await mock.waitUntilStarted(url2)
            #expect(mock.entries == 2)
            mock.release(url2)

            await #expect(throws: Error.self) { _ = try await t1.value }
            _ = try await t2.value
            #expect(mock.peakConcurrency == 1)
        }
    }
}