import DownloadKit
import Testing
import Foundation

/// Mock HTTP 客户端用于测试
final class MockHTTPClient: HTTPClient, @unchecked Sendable {
    var downloadResult: Result<Data?, Error> = .success(Data("mock content".utf8))
    var downloadDelay: Duration? = nil
    var progressUpdates: [(Int64, Int64?)] = []

    private(set) var downloadCallCount = 0
    private(set) var lastURL: URL?
    private(set) var lastDestination: URL?

    func download(
        from url: URL,
        to destination: URL,
        resumeData: Data?,
        progressHandler: @Sendable @escaping (Int64, Int64?) -> Void
    ) async throws -> Data? {
        downloadCallCount += 1
        lastURL = url
        lastDestination = destination

        // 模拟进度更新
        for (downloaded, total) in progressUpdates {
            progressHandler(downloaded, total)
        }

        // 模拟延迟
        if let delay = downloadDelay {
            try await Task.sleep(for: delay)
        }

        // 返回结果
        switch downloadResult {
        case .success(let data):
            // 写入文件到 destination
            if let data {
                try data.write(to: destination)
            }
            return data
        case .failure(let error):
            throw error
        }
    }

    func reset() {
        downloadResult = .success(Data("mock content".utf8))
        downloadDelay = nil
        progressUpdates = []
        downloadCallCount = 0
        lastURL = nil
        lastDestination = nil
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
            #expect(values.count == 3)
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
}
