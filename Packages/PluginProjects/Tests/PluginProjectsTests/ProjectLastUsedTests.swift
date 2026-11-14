import Foundation
import ProviderProject
import Testing
@testable import PluginProjects

/// 可手动设置列表与当前项目的项目能力桩，用于直接驱动 syncFromProvider。
@MainActor
private final class StubProjectsCapability: ProjectsProjectCapability {
    var projects: [ProjectInfo] = []
    var currentProject: ProjectInfo?

    func synchronizeProjects(_ projects: [ProjectInfo]) { self.projects = projects }

    func openProject(at path: String, reason: ProjectChangeReason) async throws {
        currentProject = ProjectInfo(
            name: URL(fileURLWithPath: path).lastPathComponent,
            path: path,
            language: nil
        )
    }

    func closeProject(reason: ProjectChangeReason) async { currentProject = nil }
}

/// 项目 Last Used 的回归（**#476**）：启动同步必须保留持久化的使用时间，
/// 选中/打开项目时推进其 lastUsed，且无关同步不得反复刷新时间。
@MainActor
@Suite("ProjectLastUsed（#476）")
struct ProjectLastUsedTests {
    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("ProjectLastUsed-\(UUID().uuidString)")
    }

    private let oldA = Date(timeIntervalSince1970: 1_000_000)
    private let oldB = Date(timeIntervalSince1970: 2_000_000)

    private func makeStore(
        pluginDir: URL,
        entries: [ProjectEntry]
    ) -> ProjectsStore {
        let store = ProjectsStore(pluginDirectory: pluginDir)
        store.save(projects: entries, currentProject: nil)
        return store
    }

    @Test("首次同步保留持久化的 lastUsed，不得重置为启动时刻")
    func firstSyncPreservesPersistedLastUsed() {
        let pluginDir = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: pluginDir) }
        let entryA = ProjectEntry(name: "A", path: "/tmp/lastused-A", language: nil, lastUsed: oldA)
        let entryB = ProjectEntry(name: "B", path: "/tmp/lastused-B", language: nil, lastUsed: oldB)
        let store = makeStore(pluginDir: pluginDir, entries: [entryA, entryB])

        let capability = StubProjectsCapability()
        capability.projects = [
            ProjectInfo(name: "A", path: entryA.path, language: nil),
            ProjectInfo(name: "B", path: entryB.path, language: nil),
        ]
        capability.currentProject = nil
        let viewModel = ProjectsViewModel(store: store, projectCapability: capability)

        viewModel.syncFromProvider(persist: false)

        let a = viewModel.projects.first { $0.path == entryA.path }
        let b = viewModel.projects.first { $0.path == entryB.path }
        #expect(a?.lastUsed == oldA, "首次同步必须保留持久化的 lastUsed")
        #expect(b?.lastUsed == oldB, "每个项目都应保留各自的持久化时间")
    }

    @Test("选中项目推进其 lastUsed，未选中项目不被刷新")
    func selectionAdvancesLastUsed() {
        let pluginDir = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: pluginDir) }
        let entryA = ProjectEntry(name: "A", path: "/tmp/lastused-A", language: nil, lastUsed: oldA)
        let entryB = ProjectEntry(name: "B", path: "/tmp/lastused-B", language: nil, lastUsed: oldB)
        let store = makeStore(pluginDir: pluginDir, entries: [entryA, entryB])

        let capability = StubProjectsCapability()
        capability.projects = [
            ProjectInfo(name: "A", path: entryA.path, language: nil),
            ProjectInfo(name: "B", path: entryB.path, language: nil),
        ]
        capability.currentProject = nil
        let viewModel = ProjectsViewModel(store: store, projectCapability: capability)
        viewModel.syncFromProvider(persist: false)

        // 模拟选中 A：Provider 当前项目变化后再次同步。
        capability.currentProject = ProjectInfo(name: "A", path: entryA.path, language: nil)
        viewModel.syncFromProvider(persist: false)

        let a = viewModel.projects.first { $0.path == entryA.path }
        let b = viewModel.projects.first { $0.path == entryB.path }
        #expect((a?.lastUsed ?? .distantPast) > oldA, "选中项目必须推进其 lastUsed")
        #expect(viewModel.currentProject?.path == entryA.path)
        #expect((viewModel.currentProject?.lastUsed ?? .distantPast) > oldA, "当前项目快照也应推进")
        #expect(b?.lastUsed == oldB, "未选中的项目不得被刷新")
    }

    @Test("当前项目不变时重复同步不得再次推进 lastUsed")
    func resyncWithUnchangedCurrentDoesNotAdvance() {
        let pluginDir = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: pluginDir) }
        let entryA = ProjectEntry(name: "A", path: "/tmp/lastused-A", language: nil, lastUsed: oldA)
        let store = makeStore(pluginDir: pluginDir, entries: [entryA])

        let capability = StubProjectsCapability()
        capability.projects = [ProjectInfo(name: "A", path: entryA.path, language: nil)]
        capability.currentProject = ProjectInfo(name: "A", path: entryA.path, language: nil)
        let viewModel = ProjectsViewModel(store: store, projectCapability: capability)

        viewModel.syncFromProvider(persist: false)
        let first = viewModel.projects.first { $0.path == entryA.path }?.lastUsed
        viewModel.syncFromProvider(persist: false)
        let second = viewModel.projects.first { $0.path == entryA.path }?.lastUsed

        #expect(first != nil)
        #expect(first == second, "当前项目不变时重复同步不得再次推进 lastUsed")
    }
}