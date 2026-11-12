import Foundation
import Testing

@testable import ProjectRAGEngine

/// Task 3.2：FSEvents 新鲜度监听。debounce 合并、项目身份校验、暂停不触发。
/// 单元注入走 handleEvent；真实流集成测试需要 macOS FSEvents 运行环境。
@Suite struct RAGProjectWatcherTests {
    private final class TriggerRecorder: @unchecked Sendable {
        private let lock = NSLock()
        private var calls: [String] = []
        func record(_ path: String) {
            lock.lock(); defer { lock.unlock() }
            calls.append(path)
        }
        var snapshot: [String] {
            lock.lock(); defer { lock.unlock() }
            return calls
        }
    }

    private func makeTempDir() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("rag-watcher-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func waitUntil(timeout: TimeInterval = 5, _ condition: @escaping () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        return condition()
    }

    @Test("debounce 将连续事件合并为一次触发")
    func debounceCoalescesEvents() async throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let recorder = TriggerRecorder()
        let watcher = RAGProjectWatcher(
            debounceInterval: 0.1,
            isPaused: { false },
            currentProjectPath: { dir.path },
            trigger: { recorder.record($0) }
        )
        defer { watcher.stop() }
        watcher.start(projectPath: dir.path)

        watcher.handleEvent(paths: ["a.swift"])
        watcher.handleEvent(paths: ["b.swift"])
        watcher.handleEvent(paths: ["c.swift"])

        let fired = await waitUntil(timeout: 2) { !recorder.snapshot.isEmpty }
        #expect(fired)
        try await Task.sleep(nanoseconds: 300_000_000)
        #expect(recorder.snapshot == [dir.path])
    }

    @Test("旧项目的晚到事件被身份校验丢弃")
    func staleProjectEventDropped() async throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let recorder = TriggerRecorder()
        // 当前项目已切换，但监听仍指向旧目录：触发前必须比对身份。
        let watcher = RAGProjectWatcher(
            debounceInterval: 0.05,
            isPaused: { false },
            currentProjectPath: { "/some/other/project" },
            trigger: { recorder.record($0) }
        )
        defer { watcher.stop() }
        watcher.start(projectPath: dir.path)

        watcher.handleEvent(paths: ["a.swift"])

        try await Task.sleep(nanoseconds: 400_000_000)
        #expect(recorder.snapshot.isEmpty)
    }

    @Test("索引暂停时不触发")
    func pausedWatcherDoesNotTrigger() async throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let recorder = TriggerRecorder()
        let watcher = RAGProjectWatcher(
            debounceInterval: 0.05,
            isPaused: { true },
            currentProjectPath: { dir.path },
            trigger: { recorder.record($0) }
        )
        defer { watcher.stop() }
        watcher.start(projectPath: dir.path)

        watcher.handleEvent(paths: ["a.swift"])

        try await Task.sleep(nanoseconds: 400_000_000)
        #expect(recorder.snapshot.isEmpty)
    }

    @Test("真实 FSEvents 流：写入文件后触发增量索引", .timeLimit(.minutes(1)))
    func fileEventsStreamTriggersOnWrite() async throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let recorder = TriggerRecorder()
        let watcher = RAGProjectWatcher(
            debounceInterval: 0.1,
            streamLatency: 0.1,
            isPaused: { false },
            currentProjectPath: { dir.path },
            trigger: { recorder.record($0) }
        )
        defer { watcher.stop() }
        watcher.start(projectPath: dir.path)

        try "let changed = 1\n".write(
            to: dir.appendingPathComponent("Changed.swift"),
            atomically: true,
            encoding: .utf8
        )

        let fired = await waitUntil(timeout: 10) { !recorder.snapshot.isEmpty }
        #expect(fired)
        #expect(recorder.snapshot.first == dir.path)
    }
}