import Foundation
import Testing

@testable import PluginProjectFileTree

/// 回归 #1097：视图消失时 `stop()` 会关闭 watcher，但同一根路径再次出现时
/// 旧的相等 guard 直接返回，监听不会重启，外部变更从此不再刷新文件树。
@Test("同一根路径在视图重新出现时重新挂载监听")
func sameRootPathReappearanceRestartsWatching() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("lumi-file-tree-refresh-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let watcher = RecordingFileTreeWatcher()
    let coordinator = RefreshCoordinator()
    coordinator.attach(observer: watcher)

    coordinator.setProjectRootPath(root.path)
    #expect(watcher.updatedDirectorySets.count == 1)

    let stopsBeforeDisappear = watcher.stopCount
    coordinator.stop()
    #expect(watcher.stopCount == stopsBeforeDisappear + 1)

    coordinator.setProjectRootPath(root.path)

    #expect(watcher.updatedDirectorySets.count == 2)
    #expect(watcher.updatedDirectorySets.last?.contains(root.standardizedFileURL) == true)
}

@Test("视图重新出现时仍使用此前展开的目录")
func sameRootPathReappearanceKeepsExpandedPaths() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("lumi-file-tree-refresh-\(UUID().uuidString)", isDirectory: true)
    let expanded = root.appendingPathComponent("Sources", isDirectory: true)
    try FileManager.default.createDirectory(at: expanded, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let watcher = RecordingFileTreeWatcher()
    let coordinator = RefreshCoordinator()
    coordinator.attach(observer: watcher)
    coordinator.setProjectRootPath(root.path)
    coordinator.addExpandedPath("Sources")

    coordinator.stop()
    coordinator.setProjectRootPath(root.path)

    #expect(watcher.updatedDirectorySets.count == 3)
    #expect(watcher.updatedDirectorySets.last?.contains(expanded.standardizedFileURL) == true)
}

@Test("空根路径重复设置不会启动监听")
func emptyRootPathDoesNotStartWatching() {
    let watcher = RecordingFileTreeWatcher()
    let coordinator = RefreshCoordinator()
    coordinator.attach(observer: watcher)

    coordinator.setProjectRootPath("")
    coordinator.setProjectRootPath("")

    #expect(watcher.updatedDirectorySets.isEmpty)
}

/// 回归 #1099：全量刷新曾与精准刷新共用 `debounceTask`，取消 trailing 窗口后
/// `isDebouncePending` 仍为 true，后续外部事件只累积到 pending，精准刷新永久停摆。
@MainActor
@Test("全量刷新不会让精准刷新永久停摆")
func fullRefreshDoesNotStallTargetedRefresh() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("lumi-file-tree-refresh-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let coordinator = RefreshCoordinator()
    coordinator.attach(observer: RecordingFileTreeWatcher())
    coordinator.setProjectRootPath(root.path)

    let changedFile = root.appendingPathComponent("E1.txt")
    coordinator.handleDirectoryChanged(url: changedFile)
    let firstEventPublished = await waitUntil { coordinator.targetedRefreshToken == 1 }
    #expect(firstEventPublished)

    coordinator.refresh()
    let fullRefreshRan = await waitUntil { coordinator.refreshToken == 1 }
    #expect(fullRefreshRan)

    let secondFile = root.appendingPathComponent("E2.txt")
    coordinator.handleDirectoryChanged(url: secondFile)
    let secondEventPublished = await waitUntil { coordinator.targetedRefreshToken >= 2 }
    #expect(secondEventPublished, "全量刷新后后续外部事件仍未触发精准刷新")
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

private final class RecordingFileTreeWatcher: FileTreeWatching, @unchecked Sendable {
    private(set) var updatedDirectorySets: [Set<URL>] = []
    private(set) var stopCount = 0

    func updateWatchedDirectories(_ directories: Set<URL>) {
        updatedDirectorySets.append(directories)
    }

    func stopWatching() {
        stopCount += 1
    }
}
