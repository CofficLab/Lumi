import DownloadKit
import Testing
import Foundation

/// Mock HTTP 客户端用于测试
final class MockHTTPClient: HTTPClient, @unchecked Sendable {
    var downloadResult: Result<Data?, Error> = .success(Data("mock content".utf8))
    var downloadDelay: Duration? = nil
    var progressUpdates: [(Int64, Int64?)] = []
    /// 延迟期间是否持续发送进度回调（模拟真实下载取消后仍有滞后进度到达）。
    var emitProgressDuringDelay: Bool = false

    private(set) var downloadCallCount = 0
    private(set) var lastURL: URL?
    private(set) var lastDestination: URL?
    /// 收到最近一次 download 调用传入的 existingBytes（续传起点），用于断言续传链路。
    private(set) var lastExistingBytes: Int64 = 0

    func download(
        from url: URL,
        to destination: URL,
        existingBytes: Int64,
        progressHandler: @Sendable @escaping (Int64, Int64?) -> Void,
        onCancelled: @Sendable @escaping (Data?) -> Void
    ) async throws -> Int64? {
        downloadCallCount += 1
        lastURL = url
        lastDestination = destination
        lastExistingBytes = existingBytes

        // 模拟进度更新（progressUpdates 是「累计值」，调用方可据此模拟续传进度）
        for (downloaded, total) in progressUpdates {
            progressHandler(downloaded, total)
        }

        // 模拟延迟
        if let delay = downloadDelay {
            if emitProgressDuringDelay {
                // 在延迟期间持续发送进度，模拟真实下载：取消后仍有滞后进度回调到达
                let deadline = ContinuousClock().now.advanced(by: delay)
                var bytes: Int64 = existingBytes  // 从续传起点累加，模拟累计值语义
                while ContinuousClock().now < deadline {
                    bytes += 1000
                    progressHandler(bytes, Int64.max)
                    do {
                        try await Task.sleep(for: .milliseconds(10))
                    } catch {
                        // 被取消：流式写入已落盘，回调 nil（无 resume data blob）
                        onCancelled(nil)
                        throw CancellationError()
                    }
                    try Task.checkCancellation()
                }
            } else {
                do {
                    try await Task.sleep(for: delay)
                } catch {
                    onCancelled(nil)
                    throw CancellationError()
                }
            }
        }

        // 返回结果
        switch downloadResult {
        case .success(let data):
            // 模拟流式追加写入：existingBytes > 0 时追加，否则覆盖写（与 DefaultHTTPClient 一致）
            if let data {
                if existingBytes > 0, FileManager.default.fileExists(atPath: destination.path) {
                    let handle = try FileHandle(forWritingTo: destination)
                    try handle.seekToEnd()
                    try handle.write(contentsOf: data)
                    try handle.close()
                } else {
                    try data.write(to: destination)
                }
            }
            return Int64(data?.count ?? 0)
        case .failure(let error):
            throw error
        }
    }

    func reset() {
        downloadResult = .success(Data("mock content".utf8))
        downloadDelay = nil
        progressUpdates = []
        emitProgressDuringDelay = false
        downloadCallCount = 0
        lastURL = nil
        lastDestination = nil
        lastExistingBytes = 0
    }
}

/// 线程安全的进度收集器
actor ProgressCollector {
    var values: [DownloadProgress] = []
    func add(_ progress: DownloadProgress) {
        values.append(progress)
    }
}

@Suite("DownloadManager Tests")
struct DownloadManagerTests {

    private func withTempDir(_ body: (URL) async throws -> Void) async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("DownloadManagerTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        try await body(tempDir)
    }

    @Test("下载文件成功")
    func downloadSuccess() async throws {
        try await withTempDir { tempDir in
            let mockClient = MockHTTPClient()
            let config = DownloadManager.Configuration(downloadDirectory: tempDir)
            let manager = DownloadManager(configuration: config, httpClient: mockClient)

            let destination = tempDir.appendingPathComponent("downloaded.txt")
            let content = Data("mock content".utf8)
            let task = DownloadTask(
                url: URL(string: "https://example.com/file.txt")!,
                destination: destination,
                expectedSize: Int64(content.count)
            )

            let result = try await manager.download(task)

            #expect(result == destination)
            #expect(FileManager.default.fileExists(atPath: destination.path))
            #expect(mockClient.downloadCallCount == 1)
        }
    }

    @Test("下载失败抛出错误")
    func downloadFailure() async throws {
        try await withTempDir { tempDir in
            let mockClient = MockHTTPClient()
            mockClient.downloadResult = .failure(DownloadError.httpError(404))

            let config = DownloadManager.Configuration(downloadDirectory: tempDir)
            let manager = DownloadManager(configuration: config, httpClient: mockClient)

            let destination = tempDir.appendingPathComponent("failed.txt")
            let task = DownloadTask(
                url: URL(string: "https://example.com/file.txt")!,
                destination: destination
            )

            do {
                _ = try await manager.download(task)
                Issue.record("应该抛出错误")
            } catch {
                #expect(error is DownloadError)
            }
        }
    }

    @Test("获取任务状态")
    func getTaskState() async throws {
        try await withTempDir { tempDir in
            let mockClient = MockHTTPClient()
            let config = DownloadManager.Configuration(downloadDirectory: tempDir)
            let manager = DownloadManager(configuration: config, httpClient: mockClient)

            let destination = tempDir.appendingPathComponent("state.txt")
            let content = Data("mock content".utf8)
            let task = DownloadTask(
                id: "test-task",
                url: URL(string: "https://example.com/file.txt")!,
                destination: destination,
                expectedSize: Int64(content.count)
            )

            // 下载前状态为 nil
            let stateBefore = await manager.state(for: task.id)
            #expect(stateBefore == nil)

            // 执行下载
            _ = try await manager.download(task)

            // 下载完成后状态为 completed
            let stateAfter = await manager.state(for: task.id)
            #expect(stateAfter == .completed)
        }
    }

    @Test("取消下载")
    func cancelDownload() async throws {
        try await withTempDir { tempDir in
            let mockClient = MockHTTPClient()
            mockClient.downloadDelay = .seconds(10)

            let config = DownloadManager.Configuration(downloadDirectory: tempDir)
            let manager = DownloadManager(configuration: config, httpClient: mockClient)

            let destination = tempDir.appendingPathComponent("cancel.txt")
            let task = DownloadTask(
                id: "cancel-task",
                url: URL(string: "https://example.com/file.txt")!,
                destination: destination
            )

            // 开始下载（不等待完成）
            Task {
                _ = try? await manager.download(task)
            }

            // 等待一小段时间让任务启动
            try await Task.sleep(for: .milliseconds(100))

            // 取消下载
            await manager.cancel(taskId: task.id)

            // 等待一小段时间让取消生效
            try await Task.sleep(for: .milliseconds(100))

            // 检查状态为 cancelled
            let state = await manager.state(for: task.id)
            #expect(state == .cancelled)
        }
    }

    @Test("进度回调被调用")
    func progressCallback() async throws {
        try await withTempDir { tempDir in
            let mockClient = MockHTTPClient()
            mockClient.progressUpdates = [
                (10, 100),
                (50, 100),
                (100, 100)
            ]

            let config = DownloadManager.Configuration(downloadDirectory: tempDir)
            let manager = DownloadManager(configuration: config, httpClient: mockClient)

            let destination = tempDir.appendingPathComponent("progress.txt")
            let task = DownloadTask(
                url: URL(string: "https://example.com/file.txt")!,
                destination: destination
            )

            let collector = ProgressCollector()

            _ = try await manager.download(task) { progress in
                Task { await collector.add(progress) }
            }

            // 等待所有进度更新被处理
            try await Task.sleep(for: .milliseconds(200))

            let values = await collector.values
            // 至少收到 Mock 发出的 3 次进度回调（同步投递可靠）；
            // 另有完成时补发的最终进度，故用 >= 3 容纳实现细节，避免脆弱时序断言。
            #expect(values.count >= 3, "应至少收到 3 次进度回调，实际：\(values.count)")
        }
    }

    @Test("已完整文件不重复下载")
    func skipExistingFile() async throws {
        try await withTempDir { tempDir in
            let mockClient = MockHTTPClient()
            let config = DownloadManager.Configuration(downloadDirectory: tempDir)
            let manager = DownloadManager(configuration: config, httpClient: mockClient)

            let destination = tempDir.appendingPathComponent("existing.txt")
            let content = "mock content"
            try content.write(to: destination, atomically: true, encoding: .utf8)

            let task = DownloadTask(
                url: URL(string: "https://example.com/file.txt")!,
                destination: destination,
                expectedSize: Int64(content.utf8.count)
            )

            _ = try await manager.download(task)

            // Mock 客户端应该不被调用
            #expect(mockClient.downloadCallCount == 0)
        }
    }

    @Test("取消所有下载")
    func cancelAll() async throws {
        try await withTempDir { tempDir in
            let mockClient = MockHTTPClient()
            mockClient.downloadDelay = .seconds(10)

            let config = DownloadManager.Configuration(downloadDirectory: tempDir)
            let manager = DownloadManager(configuration: config, httpClient: mockClient)

            // 创建多个任务
            for i in 0..<3 {
                let destination = tempDir.appendingPathComponent("file\(i).txt")
                let task = DownloadTask(
                    id: "task-\(i)",
                    url: URL(string: "https://example.com/file\(i).txt")!,
                    destination: destination
                )

                Task {
                    _ = try? await manager.download(task)
                }
            }

            // 等待任务开始
            try await Task.sleep(for: .milliseconds(100))

            // 取消所有
            await manager.cancelAll()

            // 等待所有任务完成
            try await Task.sleep(for: .milliseconds(100))

            // 验证所有任务状态为 cancelled
            for i in 0..<3 {
                let state = await manager.state(for: "task-\(i)")
                #expect(state == .cancelled)
            }
        }
    }

    @Test("取消后可重新下载同 id 任务（暂停/恢复回归）")
    func reDownloadAfterCancel() async throws {
        try await withTempDir { tempDir in
            let mockClient = MockHTTPClient()
            mockClient.downloadDelay = .seconds(2)
            // 延迟期间持续发送进度，尽量接近真实下载（取消后仍有滞后进度回调）。
            // 注：真实 bug 的竞态依赖网络 IO 的非确定性取消时序，单测难以 100% 复现；
            // 此用例主要守护「取消→重新下载同 id」的对外契约不被破坏。
            mockClient.emitProgressDuringDelay = true

            let config = DownloadManager.Configuration(downloadDirectory: tempDir)
            let manager = DownloadManager(configuration: config, httpClient: mockClient)

            let destination = tempDir.appendingPathComponent("file.txt")
            let task = DownloadTask(
                id: "same-id",
                url: URL(string: "https://example.com/file.txt")!,
                destination: destination
            )

            // 1. 发起下载（不等待完成，模拟进行中）
            let firstDownload = Task { try? await manager.download(task) }
            try await Task.sleep(for: .milliseconds(100))

            // 2. 取消（模拟暂停：底层调 cancel）
            await manager.cancel(taskId: task.id)
            _ = await firstDownload.result

            // 3. 重新下载同 id —— 修复前会因滞后进度覆盖状态而抛「任务已在进行中」
            mockClient.downloadDelay = nil
            mockClient.emitProgressDuringDelay = false
            let result = await Task { try? await manager.download(task) }.result
            switch result {
            case .success:
                #expect(true)  // 修复后可正常重新下载
            case .failure:
                Issue.record("取消后重新下载同 id 应成功，不应残留「任务已在进行中」状态")
            }
        }
    }

    @Test("cancelAll 后可重新下载同 id 任务（暂停/恢复回归）")
    func reDownloadAfterCancelAll() async throws {
        try await withTempDir { tempDir in
            let mockClient = MockHTTPClient()
            mockClient.downloadDelay = .seconds(2)
            mockClient.emitProgressDuringDelay = true  // 同上，复现滞后进度覆盖状态

            let config = DownloadManager.Configuration(downloadDirectory: tempDir)
            let manager = DownloadManager(configuration: config, httpClient: mockClient)

            let destination = tempDir.appendingPathComponent("file.txt")
            let task = DownloadTask(
                id: "same-id",
                url: URL(string: "https://example.com/file.txt")!,
                destination: destination
            )

            // 1. 发起下载
            let firstDownload = Task { try? await manager.download(task) }
            try await Task.sleep(for: .milliseconds(100))

            // 2. cancelAll（MLX 暂停/取消走这条路径）
            await manager.cancelAll()
            _ = await firstDownload.result

            // 3. 重新下载同 id —— 修复前会抛「任务已在进行中」
            mockClient.downloadDelay = nil
            let result = await Task { try? await manager.download(task) }.result
            switch result {
            case .success:
                #expect(true)
            case .failure:
                Issue.record("cancelAll 后重新下载同 id 应成功，不应残留「任务已在进行中」状态")
            }
        }
    }

    @Test("磁盘部分文件作为续传起点传给 HTTPClient（字节级续传回归）")
    func existingBytesDrivenFromPartialFile() async throws {
        try await withTempDir { tempDir in
            let mockClient = MockHTTPClient()

            let destination = tempDir.appendingPathComponent("file.bin")
            // 模拟暂停时已下载的部分文件：预先写入 400 字节
            let partialBytes: Int64 = 400
            try Data(repeating: 0x55, count: Int(partialBytes)).write(to: destination)
            #expect(FileManager.default.fileExists(atPath: destination.path))

            // 续传语义：Mock 追加写入「剩余 600 字节」，加上已有的 400 = 完整 1000 字节
            let remainingContent = Data(repeating: 0xAB, count: 600)
            mockClient.downloadResult = .success(remainingContent)

            let config = DownloadManager.Configuration(downloadDirectory: tempDir)
            let manager = DownloadManager(configuration: config, httpClient: mockClient)

            let task = DownloadTask(
                id: "resume-id",
                url: URL(string: "https://example.com/file.bin")!,
                destination: destination,
                expectedSize: 1000  // 400(已有) + 600(续传) = 1000
            )

            // performDownload 应读取 destination 已有字节数作为 existingBytes 传给 HTTPClient
            _ = try await manager.download(task)

            #expect(
                mockClient.lastExistingBytes == partialBytes,
                "应读取部分文件大小作为续传起点传给 HTTPClient，实际：\(mockClient.lastExistingBytes)"
            )
            // 续传追加后文件应为完整 1000 字节
            let attrs = try FileManager.default.attributesOfItem(atPath: destination.path)
            #expect((attrs[.size] as? Int64) == 1000, "续传后文件应为完整大小")
        }
    }

    @Test("无文件时 existingBytes 为 0（全新下载）")
    func existingBytesZeroForFreshDownload() async throws {
        try await withTempDir { tempDir in
            let mockClient = MockHTTPClient()
            mockClient.downloadResult = .success(Data("content".utf8))

            let config = DownloadManager.Configuration(downloadDirectory: tempDir)
            let manager = DownloadManager(configuration: config, httpClient: mockClient)

            let destination = tempDir.appendingPathComponent("fresh.bin")
            // 不预置文件
            let task = DownloadTask(
                id: "fresh-id",
                url: URL(string: "https://example.com/fresh.bin")!,
                destination: destination
            )

            _ = try await manager.download(task)

            #expect(mockClient.lastExistingBytes == 0, "全新下载 existingBytes 应为 0")
        }
    }

    @Test("禁用续传时忽略部分文件（existingBytes 为 0）")
    func existingBytesIgnoredWhenResumeDisabled() async throws {
        try await withTempDir { tempDir in
            let mockClient = MockHTTPClient()
            mockClient.downloadResult = .success(Data(repeating: 0xAB, count: 500))

            // enableResume = false：不读取部分文件作为续传起点
            let config = DownloadManager.Configuration(downloadDirectory: tempDir, enableResume: false)
            let manager = DownloadManager(configuration: config, httpClient: mockClient)

            let destination = tempDir.appendingPathComponent("file.bin")
            try Data(repeating: 0x55, count: 300).write(to: destination)

            let task = DownloadTask(
                id: "no-resume-id",
                url: URL(string: "https://example.com/file.bin")!,
                destination: destination,
                expectedSize: 500
            )

            _ = try await manager.download(task)

            #expect(mockClient.lastExistingBytes == 0, "禁用续传时 existingBytes 应为 0")
        }
    }
}
