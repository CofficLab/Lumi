import KitDownload
import Testing
import Foundation

/// 取消探针 HTTP 客户端：进入 download 后挂起轮询，直到被放行或观察到 Task 取消。
///
/// download 运行在 DownloadManager 派生的非结构化 Task 上下文里。只有当调用方的
/// 取消被显式转发到该 Task 时，这里的 `Task.isCancelled` 才会变真。据此把
/// 「取消调用方是否真正停掉内部下载」变成确定性回归（#471）。
private final class CancellationProbeHTTPClient: HTTPClient, @unchecked Sendable {
    struct ProbeTimeout: Error {}

    private let lock = NSLock()
    private var started: Set<URL> = []
    private var cancelled: Set<URL> = []
    private var released: Set<URL> = []

    func waitUntilEntered(_ url: URL, timeout: TimeInterval = 2) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if hasEntered(url) { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        throw ProbeTimeout()
    }

    func waitUntilCancelled(_ url: URL, timeout: TimeInterval = 2) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if hasCancelled(url) { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        throw ProbeTimeout()
    }

    func observedCancellation(_ url: URL) -> Bool { hasCancelled(url) }

    private func hasEntered(_ url: URL) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return started.contains(url)
    }

    private func hasCancelled(_ url: URL) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return cancelled.contains(url)
    }

    func release(_ url: URL) {
        lock.lock(); released.insert(url); lock.unlock()
    }

    private func isReleased(_ url: URL) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return released.contains(url)
    }

    private func markEntered(_ url: URL) {
        lock.lock(); started.insert(url); lock.unlock()
    }

    private func markCancelled(_ url: URL) {
        lock.lock(); cancelled.insert(url); lock.unlock()
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
        while true {
            if Task.isCancelled {
                markCancelled(url)
                throw CancellationError()
            }
            if isReleased(url) { break }
            try? await Task.sleep(for: .milliseconds(5))
        }
        let data = Data("mock content".utf8)
        try data.write(to: destination)
        return Int64(data.count)
    }
}

@Suite("DownloadManager 取消转发回归（#471）")
struct DownloadCancellationPropagationTests {

    private func withTempDir(_ body: (URL) async throws -> Void) async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("DownloadCancellationPropagationTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        try await body(tempDir)
    }

    @Test("取消调用方任务必须把取消转发到内部下载（回归 #471）")
    func cancellingCallerCancelsInternalDownload() async throws {
        try await withTempDir { tempDir in
            let url = URL(string: "https://example.com/cancel")!
            let probe = CancellationProbeHTTPClient()
            let manager = DownloadManager(
                configuration: .init(downloadDirectory: tempDir),
                httpClient: probe
            )
            let destination = tempDir.appendingPathComponent("c.bin")
            defer { probe.release(url) }

            let caller = Task { try await manager.download(
                DownloadTask(id: "c", url: url, destination: destination)
            ) }
            try await probe.waitUntilEntered(url)

            caller.cancel()

            // 内部下载必须观察到取消；否则 HTTP 请求与文件写入会跑到自然结束。
            try await probe.waitUntilCancelled(url)
            #expect(probe.observedCancellation(url), "调用方取消未转发到内部下载任务")
            await #expect(throws: Error.self) { _ = try await caller.value }
        }
    }

    @Test("取消调用方后任务进入 cancelled 态且不再写文件（回归 #471）")
    func cancelledCallerReportsCancelledStateAndStopsWrite() async throws {
        try await withTempDir { tempDir in
            let url = URL(string: "https://example.com/cancel-state")!
            let probe = CancellationProbeHTTPClient()
            let manager = DownloadManager(
                configuration: .init(downloadDirectory: tempDir),
                httpClient: probe
            )
            let destination = tempDir.appendingPathComponent("cs.bin")
            defer { probe.release(url) }

            let caller = Task { try await manager.download(
                DownloadTask(id: "cs", url: url, destination: destination)
            ) }
            try await probe.waitUntilEntered(url)

            caller.cancel()
            try await probe.waitUntilCancelled(url)
            await #expect(throws: DownloadError.self) { _ = try await caller.value }

            #expect(probe.observedCancellation(url))
            let cancelledState = await manager.state(for: "cs")
            #expect(cancelledState == .cancelled, "取消后任务状态必须为 cancelled")
            #expect(!FileManager.default.fileExists(atPath: destination.path), "取消后不得继续写出文件")
        }
    }

    @Test("未取消的下载仍正常完成（取消转发不得误伤正常路径）")
    func uncancelledDownloadStillCompletes() async throws {
        try await withTempDir { tempDir in
            let url = URL(string: "https://example.com/ok")!
            let probe = CancellationProbeHTTPClient()
            let manager = DownloadManager(
                configuration: .init(downloadDirectory: tempDir),
                httpClient: probe
            )
            let destination = tempDir.appendingPathComponent("ok.bin")

            let caller = Task { try await manager.download(
                DownloadTask(id: "ok", url: url, destination: destination)
            ) }
            try await probe.waitUntilEntered(url)
            probe.release(url)

            let result = try await caller.value
            #expect(result == destination)
            let completedState = await manager.state(for: "ok")
            #expect(completedState == .completed)
            #expect(!probe.observedCancellation(url), "正常下载不得被误取消")
            #expect(FileManager.default.fileExists(atPath: destination.path))
        }
    }
}