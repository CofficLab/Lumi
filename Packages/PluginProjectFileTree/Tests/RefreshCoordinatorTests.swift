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
