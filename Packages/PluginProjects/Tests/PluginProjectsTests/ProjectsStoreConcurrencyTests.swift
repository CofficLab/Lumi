import Foundation
import Testing
@testable import PluginProjects
import ProviderProject

/// 并发持久化测试（Issue #126）。
///
/// `ProjectsStore.save` 是 `nonisolated`，可从后台线程并发调用。修复前所有并发写共用
/// 同一个 `<文件名>.tmp`，会互相踩踏临时文件，导致后写入的数据被静默删除。
@MainActor
@Suite("ProjectsStore 并发写入")
struct ProjectsStoreConcurrencyTests {
    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("ProjectsStoreConcurrency-\(UUID().uuidString)")
    }

    /// 并发写入后，最终文件必须是**某一次写入的完整快照**，而不是损坏的 JSON。
    ///
    /// 修复前的失效模式：临时文件被其它线程覆盖/删除，导致 `replaceItemAt` 抛错并把
    /// 对方的待写内容一起删掉，最终 `projects.json` 缺失或内容不完整。
    @Test func concurrentSavesLeaveReadableFile() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = ProjectsStore(pluginDirectory: directory)

        // 每个任务写入一个内容明显不同的快照，便于断言最终文件是完整的一份。
        let snapshots: [[ProjectEntry]] = (0 ..< 24).map { index in
            (0 ..< 10).map { inner in
                ProjectEntry(name: "P\(index)-\(inner)", path: "/tmp/p\(index)-\(inner)")
            }
        }

        await withTaskGroup(of: Void.self) { group in
            for snapshot in snapshots {
                group.addTask {
                    // `save` 是 nonisolated，可在后台线程并发执行。
                    store.save(projects: snapshot, currentProject: snapshot.first)
                }
            }
        }

        // 文件必须存在且可解析。
        let reloaded = ProjectsStore(pluginDirectory: directory)
        let projects = reloaded.loadProjects()

        #expect(!projects.isEmpty)
        // 内容必须是某一份完整快照：数量一致，且 id 集合来自同一批次。
        #expect(projects.count == snapshots.first?.count)
        let firstPrefix = projects.first?.name.split(separator: "-").first
        #expect(projects.allSatisfy { $0.name.split(separator: "-").first == firstPrefix })
    }

    /// 并发写入不应留下残留的临时文件。
    @Test func concurrentSavesLeaveNoTemporaryFiles() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = ProjectsStore(pluginDirectory: directory)

        await withTaskGroup(of: Void.self) { group in
            for index in 0 ..< 24 {
                group.addTask {
                    let entry = ProjectEntry(name: "P\(index)", path: "/tmp/p\(index)")
                    store.save(projects: [entry], currentProject: entry)
                }
            }
        }

        let settingsDirectory = directory.appendingPathComponent("settings", isDirectory: true)
        let contents = try FileManager.default.contentsOfDirectory(atPath: settingsDirectory.path)
        let leftovers = contents.filter { $0.hasSuffix(".tmp") }

        #expect(leftovers.isEmpty)
    }
}
