import Foundation
import ProviderProject
import Testing

@testable import PluginProjectFileTree

/// 回归 #570：Explorer 里展开一个此前折叠的目录时，`TreeView.handleExpansionChange`
/// 只把展开状态写进 `FileTreeSettings`，从不调用 `RefreshCoordinator.addExpandedPath`，
/// 新展开的目录因此 never 进入 watcher，外部新增文件不会自动刷新（折叠同理不移除监听）。
///
/// 这里构造真实 `TreeView` + `RefreshCoordinator` + 记录型 watcher，直接驱动生产回调
/// `handleExpansionChange`，断言展开/折叠会同步更新 watcher 的监听列表。
/// 用真实临时目录 + 默认探测，走与生产一致的磁盘判定路径。
@MainActor
@Suite("展开状态同步到 watcher", .serialized)
struct TreeViewExpansionWatchTests {

    @Test("展开目录会把该目录加入 watcher 监听列表")
    func expandRegistersDirectoryWithWatcher() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi-tree-expand-\(UUID().uuidString)", isDirectory: true)
        let sources = root.appendingPathComponent("Sources", isDirectory: true)
        try FileManager.default.createDirectory(at: sources, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let watcher = RecordingExpansionWatcher()
        let coordinator = RefreshCoordinator(gitStatusEnabled: false)
        coordinator.attach(observer: watcher)
        let tree = makeTreeView(projectRoot: root.path, coordinator: coordinator)

        coordinator.setProjectRootPath(root.path)
        #expect(await waitUntil { watcher.updatedDirectorySets.count == 1 })

        tree.handleExpansionChange(relativePath: "Sources", isExpanded: true)
        #expect(await waitUntil { watcher.updatedDirectorySets.count == 2 })

        let applied = try #require(watcher.updatedDirectorySets.last)
        #expect(applied.contains(sources.standardizedFileURL), "新展开的目录必须进入监听列表")
    }

    @Test("折叠目录会把该目录从 watcher 监听列表移除")
    func collapseRemovesDirectoryFromWatcher() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi-tree-expand-\(UUID().uuidString)", isDirectory: true)
        let sources = root.appendingPathComponent("Sources", isDirectory: true)
        try FileManager.default.createDirectory(at: sources, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let watcher = RecordingExpansionWatcher()
        let coordinator = RefreshCoordinator(gitStatusEnabled: false)
        coordinator.attach(observer: watcher)
        let tree = makeTreeView(projectRoot: root.path, coordinator: coordinator)

        coordinator.setProjectRootPath(root.path)
        #expect(await waitUntil { watcher.updatedDirectorySets.count == 1 })

        tree.handleExpansionChange(relativePath: "Sources", isExpanded: true)
        #expect(await waitUntil { watcher.updatedDirectorySets.count == 2 })
        #expect(watcher.updatedDirectorySets.last?.contains(sources.standardizedFileURL) == true)

        tree.handleExpansionChange(relativePath: "Sources", isExpanded: false)
        #expect(await waitUntil { watcher.updatedDirectorySets.count == 3 })

        let applied = try #require(watcher.updatedDirectorySets.last)
        #expect(!applied.contains(sources.standardizedFileURL), "折叠后的目录必须移出监听列表")
        #expect(applied.contains(root.standardizedFileURL), "根目录始终保留在监听列表")
    }
}

// MARK: - Helpers

@MainActor
private func makeTreeView(projectRoot: String, coordinator: RefreshCoordinator) -> TreeView {
    let viewModel = ProjectFileTreeViewModel()
    viewModel.updateCurrentProject(ProjectInfo(name: "P", path: projectRoot))
    return TreeView(
        context: FileTreeContext(project: nil, conversationInput: nil, toast: nil),
        viewModel: viewModel,
        coordinator: coordinator,
        packageStore: PackageDependencyStore()
    )
}

private final class RecordingExpansionWatcher: FileTreeWatching, @unchecked Sendable {
    private(set) var updatedDirectorySets: [Set<URL>] = []
    private(set) var stopCount = 0

    func updateWatchedDirectories(_ directories: Set<URL>) {
        updatedDirectorySets.append(directories)
    }

    func stopWatching() {
        stopCount += 1
    }
}

@MainActor
private func waitUntil(
    timeout: TimeInterval = 2,
    _ condition: () -> Bool
) async -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if condition() { return true }
        try? await Task.sleep(nanoseconds: 10_000_000)
    }
    return condition()
}