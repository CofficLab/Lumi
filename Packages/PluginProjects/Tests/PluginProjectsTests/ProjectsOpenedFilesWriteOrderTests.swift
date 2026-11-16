import Foundation
import Testing
@testable import PluginProjects

/// 打开文件记录的后台持久化（见 issue #1238）。
///
/// 每次导航都会提交一份「所有项目」的完整快照。修复前每份快照各自
/// `Task.detached` 落盘，互不排序：晚到的旧快照可能覆盖新状态，而且连续
/// 导航会把同样的全量编码/写入重复 N 次。修复后写入串行且合并，磁盘上
/// 最终一定是最新的一份。
@MainActor
@Suite("打开文件持久化顺序")
struct ProjectsOpenedFilesWriteOrderTests {
    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("ProjectsOpenedFilesOrder-\(UUID().uuidString)")
    }

    private func snapshot(_ marker: String) -> [String: ProjectOpenedFiles] {
        let file = URL(fileURLWithPath: "/tmp/demo/\(marker).swift")
        return [
            ProjectsStore.normalizedPath("/tmp/demo"): ProjectOpenedFiles(
                openFileURLs: [file],
                currentFileURL: file
            )
        ]
    }

    private func makeStore(
        directory: URL,
        writer: RecordingOpenedFilesWriter
    ) -> ProjectsStore {
        ProjectsStore(pluginDirectory: directory) { snapshot, fileURL in
            await writer.write(snapshot, to: fileURL)
        }
    }

    @Test("编码与写入不在主线程执行")
    func writeRunsOffMainThread() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let writer = RecordingOpenedFilesWriter()
        let store = makeStore(directory: directory, writer: writer)

        await store.saveOpenedFiles(snapshot("first")).value

        let sawMainThread = await writer.sawMainThread
        #expect(sawMainThread == false)
        let reloaded = ProjectsStore(pluginDirectory: directory).loadOpenedFiles()
        #expect(reloaded == snapshot("first"))
    }

    @Test("晚到的旧快照不覆盖新快照")
    func staleWriteDoesNotOverwriteNewerSnapshot() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let writer = RecordingOpenedFilesWriter()
        let store = makeStore(directory: directory, writer: writer)

        // 卡住第一份写入，构造「旧请求晚到」。
        await writer.armGate()
        let stale = store.saveOpenedFiles(snapshot("old"))
        await writer.waitUntilArmed()

        let newer = store.saveOpenedFiles(snapshot("new"))
        await writer.release()
        await stale.value
        await newer.value

        let last = await writer.lastSnapshot
        #expect(last == snapshot("new"), "最后一次落盘必须是新快照")
        let reloaded = ProjectsStore(pluginDirectory: directory).loadOpenedFiles()
        #expect(reloaded == snapshot("new"))
    }

    @Test("连续导航合并成一次写入")
    func continuousNavigationCoalescesWrites() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let writer = RecordingOpenedFilesWriter()
        let store = makeStore(directory: directory, writer: writer)

        await writer.armGate()
        _ = store.saveOpenedFiles(snapshot("step-0"))
        await writer.waitUntilArmed()

        var lastTask: Task<Void, Never>?
        for index in 1..<6 {
            lastTask = store.saveOpenedFiles(snapshot("step-\(index)"))
        }
        await writer.release()
        await lastTask?.value

        let count = await writer.writeCount
        #expect(count == 2, "被取代的中间快照不应再落盘")
        let reloaded = ProjectsStore(pluginDirectory: directory).loadOpenedFiles()
        #expect(reloaded == snapshot("step-5"))
    }

    @Test("真实写入路径下最终磁盘内容是最新快照")
    func rapidSavesLeaveLatestSnapshotOnDisk() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ProjectsStore(pluginDirectory: directory)

        var lastTask: Task<Void, Never>?
        for index in 0..<30 {
            lastTask = store.saveOpenedFiles(snapshot("file-\(index)"))
        }
        await lastTask?.value

        let reloaded = ProjectsStore(pluginDirectory: directory).loadOpenedFiles()
        #expect(reloaded == snapshot("file-29"))

        let settingsDirectory = directory.appendingPathComponent("settings", isDirectory: true)
        let contents = try FileManager.default.contentsOfDirectory(atPath: settingsDirectory.path)
        #expect(contents.filter { $0.hasSuffix(".tmp") }.isEmpty)
    }

    @Test("内存缓存立即更新，不等磁盘写入")
    func cacheUpdatesBeforeWriteCompletes() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let writer = RecordingOpenedFilesWriter()
        let store = makeStore(directory: directory, writer: writer)

        await writer.armGate()
        let task = store.saveOpenedFiles(snapshot("pending"))
        await writer.waitUntilArmed()

        // 写入还卡在门闩上，缓存与修订号已经更新。
        #expect(store.loadOpenedFiles() == snapshot("pending"))
        #expect(store.openedFilesRevision == 1)

        await writer.release()
        await task.value
    }
}

// MARK: - 测试替身

/// 记录落盘线程/次数/内容，并可卡住某一次写入；同时把快照真实写到磁盘。
private actor RecordingOpenedFilesWriter {
    private(set) var writeCount = 0
    private(set) var sawMainThread: Bool?
    private(set) var lastSnapshot: [String: ProjectOpenedFiles]?
    private var gate: CheckedContinuation<Void, Never>?
    private var blockNextWrite = false

    func write(_ snapshot: [String: ProjectOpenedFiles], to url: URL) async {
        writeCount += 1
        sawMainThread = Self.isOnMainThread()
        lastSnapshot = snapshot
        if blockNextWrite {
            blockNextWrite = false
            await withCheckedContinuation { continuation in
                gate = continuation
            }
        }
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? JSONEncoder().encode(snapshot).write(to: url, options: .atomic)
    }

    func armGate() {
        blockNextWrite = true
    }

    func waitUntilArmed() async {
        while gate == nil {
            await Task.yield()
        }
    }

    func release() {
        gate?.resume()
        gate = nil
    }

    nonisolated private static func isOnMainThread() -> Bool {
        Thread.isMainThread
    }
}
