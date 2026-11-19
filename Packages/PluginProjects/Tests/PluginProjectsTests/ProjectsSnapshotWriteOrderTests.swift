import Foundation
import Testing
@testable import PluginProjects

/// 项目/当前项目快照的后台持久化（见 issue #193）。
///
/// 每次同步都提交一份全量快照。修复前每份快照各自 `Task.detached` 落盘，
/// 互不排序：调度颠倒写入顺序时，晚到的旧快照会把磁盘上的新状态覆盖回去，
/// 重启后恢复出错误的当前项目。修复后写入串行且合并，磁盘上最终一定是
/// 最后提交的一份。
@MainActor
@Suite("项目快照持久化顺序")
struct ProjectsSnapshotWriteOrderTests {
    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("ProjectsSnapshotOrder-\(UUID().uuidString)")
    }

    private func project(_ marker: String) -> ProjectEntry {
        ProjectEntry(
            name: marker,
            path: "/tmp/demo/\(marker)",
            language: nil
        )
    }

    private func makeStore(
        directory: URL,
        writer: RecordingProjectsWriter
    ) -> ProjectsStore {
        ProjectsStore(pluginDirectory: directory, projectsWriter: { projects, currentProject, projectsURL, currentProjectURL in
            await writer.write(projects, currentProject, to: projectsURL, currentProjectURL: currentProjectURL)
        })
    }

    @Test("晚到的旧快照不覆盖新快照")
    func staleWriteDoesNotOverwriteNewerSnapshot() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let writer = RecordingProjectsWriter()
        let store = makeStore(directory: directory, writer: writer)

        // 卡住第一份写入，构造「旧请求晚到」。
        await writer.armGate()
        let stale = store.saveSnapshot(projects: [project("old")], currentProject: project("old"))
        await writer.waitUntilArmed()

        let newer = store.saveSnapshot(projects: [project("new")], currentProject: project("new"))
        await writer.release()
        await stale.value
        await newer.value

        let last = await writer.lastCurrentPath
        #expect(last == "/tmp/demo/new", "最后一次落盘必须是新快照")
        let reloaded = ProjectsStore(pluginDirectory: directory)
        #expect(reloaded.loadCurrentProjectPath() == "/tmp/demo/new")
    }

    @Test("连续同步合并成一次写入")
    func continuousSyncsCoalesceWrites() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let writer = RecordingProjectsWriter()
        let store = makeStore(directory: directory, writer: writer)

        await writer.armGate()
        _ = store.saveSnapshot(projects: [project("step-0")], currentProject: project("step-0"))
        await writer.waitUntilArmed()

        var lastTask: Task<Void, Never>?
        for index in 1..<6 {
            lastTask = store.saveSnapshot(
                projects: [project("step-\(index)")],
                currentProject: project("step-\(index)")
            )
        }
        await writer.release()
        await lastTask?.value

        let count = await writer.writeCount
        #expect(count == 2, "被取代的中间快照不应再落盘")
        let reloaded = ProjectsStore(pluginDirectory: directory)
        #expect(reloaded.loadCurrentProjectPath() == "/tmp/demo/step-5")
    }

    @Test("真实写入路径下最终磁盘内容是最新快照")
    func rapidSavesLeaveLatestSnapshotOnDisk() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ProjectsStore(pluginDirectory: directory)

        var lastTask: Task<Void, Never>?
        for index in 0..<30 {
            lastTask = store.saveSnapshot(
                projects: [project("p-\(index)")],
                currentProject: project("p-\(index)")
            )
        }
        await lastTask?.value

        let reloaded = ProjectsStore(pluginDirectory: directory)
        #expect(reloaded.loadProjects().map(\.path) == ["/tmp/demo/p-29"])
        #expect(reloaded.loadCurrentProjectPath() == "/tmp/demo/p-29")

        let contents = try FileManager.default.contentsOfDirectory(atPath: store.settingsDirectory.path)
        #expect(contents.filter { $0.hasSuffix(".tmp") }.isEmpty)
    }
}

// MARK: - 测试替身

/// 记录落盘次数/内容，并可卡住某一次写入；同时把快照真实写到磁盘。
private actor RecordingProjectsWriter {
    private(set) var writeCount = 0
    private(set) var lastCurrentPath: String?
    private var gate: CheckedContinuation<Void, Never>?
    private var blockNextWrite = false

    func write(
        _ projects: [ProjectEntry],
        _ currentProject: ProjectEntry?,
        to projectsURL: URL,
        currentProjectURL: URL
    ) async {
        writeCount += 1
        lastCurrentPath = currentProject?.path
        if blockNextWrite {
            blockNextWrite = false
            await withCheckedContinuation { continuation in
                gate = continuation
            }
        }
        try? FileManager.default.createDirectory(
            at: projectsURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? JSONEncoder().encode(projects).write(to: projectsURL, options: .atomic)
        try? JSONEncoder().encode(currentProject?.path).write(to: currentProjectURL, options: .atomic)
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
}
