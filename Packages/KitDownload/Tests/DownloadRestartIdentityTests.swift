import KitDownload
import Testing
import Foundation

/// 门控 HTTP 客户端：把指定 URL 的下载挂起在续体上，直到测试显式 release。
///
/// 续体不响应 Task 取消，因此 cancel(taskId:) 只会标记任务取消，而被挂起的下载
/// 仍停在原处——测试据此精确控制「旧任务的取消收尾晚于新任务启动」的时序，
/// 把 #157 的非确定性网络竞态变成确定性回归。release 时按 URL 决定抛取消还是成功。
private final class GatedHTTPClient: HTTPClient, @unchecked Sendable {
    struct GateTimeout: Error {}

    private let lock = NSLock()
    private var started: Set<URL> = []
    private var released: Set<URL> = []
    private var gates: [URL: CheckedContinuation<Void, Never>] = [:]
    private let gatedURLs: Set<URL>
    private let cancelOnRelease: Set<URL>

    init(gatedURLs: Set<URL>, cancelOnRelease: Set<URL>) {
        self.gatedURLs = gatedURLs
        self.cancelOnRelease = cancelOnRelease
    }

    func waitUntilStarted(_ url: URL, timeout: TimeInterval = 2) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if hasStarted(url) { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        throw GateTimeout()
    }

    private func hasStarted(_ url: URL) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return started.contains(url)
    }

    private func markStarted(_ url: URL) {
        lock.lock()
        started.insert(url)
        lock.unlock()
    }

    func release(_ url: URL) {
        lock.lock()
        released.insert(url)
        let gate = gates.removeValue(forKey: url)
        lock.unlock()
        gate?.resume()
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
        if gatedURLs.contains(url) {
            markStarted(url)
            await awaitRelease(url)
            if cancelOnRelease.contains(url) {
                throw CancellationError()
            }
        }
        let data = Data("mock content".utf8)
        try data.write(to: destination)
        return Int64(data.count)
    }
}

@Suite("DownloadManager 同 id 重启身份回归（#157）")
struct DownloadRestartIdentityTests {

    private func withTempDir(_ body: (URL) async throws -> Void) async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("DownloadRestartIdentityTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        try await body(tempDir)
    }

    @Test("取消后以同 id 重启，旧任务的晚到收尾不得取消或注销新任务")
    func cancelledTaskLateCleanupDoesNotAffectRestartedSameID() async throws {
        try await withTempDir { tempDir in
            let urlA = URL(string: "https://example.com/a")!
            let urlB = URL(string: "https://example.com/b")!
            let urlC = URL(string: "https://example.com/c")!
            let mock = GatedHTTPClient(gatedURLs: [urlA, urlB], cancelOnRelease: [urlA])
            let manager = DownloadManager(
                configuration: .init(downloadDirectory: tempDir),
                httpClient: mock
            )
            let destination = tempDir.appendingPathComponent("file.bin")
            let sharedID = "shared-id"

            // 1. 启动 A：注册 activeTasks 后挂起在门控下载里。
            let taskA = Task { try await manager.download(
                DownloadTask(id: sharedID, url: urlA, destination: destination)
            ) }
            try await mock.waitUntilStarted(urlA)

            // 2. 取消 A：立即移除 activeTasks 并置 .cancelled，但 A 的网络请求尚未结束。
            await manager.cancel(taskId: sharedID)

            // 3. 以同 id 启动 B：通过去重检查、注册新 activeTasks，挂起在门控下载里。
            let taskB = Task { try await manager.download(
                DownloadTask(id: sharedID, url: urlB, destination: destination)
            ) }
            try await mock.waitUntilStarted(urlB)

            // 4. 此刻才让 A 的已取消请求结束：A 抛 CancellationError 并执行晚到收尾。
            mock.release(urlA)
            await #expect(throws: DownloadError.self) { try await taskA.value }

            // 5. A 的晚到终态不得把 B 的状态改成 .cancelled。
            let stateAfter = await manager.state(for: sharedID)
            #expect(stateAfter != .cancelled, "旧任务把新任务状态覆盖成了 .cancelled")
            #expect(stateAfter?.isFinal == false, "新任务应仍在下载中")

            // 6. A 的晚到清理不得注销 B：同 id 的第三个下载仍应被去重拒绝。
            //    （B 若被注销，C 会通过去重并立即完成，#expect(throws:) 失败。）
            await #expect(throws: DownloadError.self) {
                try await manager.download(
                    DownloadTask(id: sharedID, url: urlC, destination: destination)
                )
            }

            // 收尾：放行 B，避免遗留挂起任务。
            mock.release(urlB)
            _ = try? await taskB.value
        }
    }
}