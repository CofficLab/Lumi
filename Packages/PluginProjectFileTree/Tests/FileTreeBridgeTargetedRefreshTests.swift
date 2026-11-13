import Foundation
import Testing

@testable import PluginProjectFileTree

/// 回归 #183：外部在项目根目录增删文件时，watcher 下发的变化集合只含根路径，
/// 旧 bridge 直接 `continue` 跳过根目录，而 `reloadDirectory(at: root)` 本身
/// 也无法命中（根不是 items 节点），导致根级子节点永远不刷新。
@MainActor
@Test("根目录变化触发全量重建而不是被跳过")
func rootOnlyChangeTriggersFullRefresh() {
    let coordinator = FileTreeNSViewBridge.Coordinator()
    let view = RecordingRefreshView()
    let root = "/tmp/lumi-file-tree-root-refresh"

    coordinator.applyTargetedRefresh(
        token: 1,
        changedPaths: [root],
        projectRootPath: root,
        to: view
    )

    #expect(view.fullRefreshCount == 1)
    #expect(view.reloadedURLs.isEmpty)
}

@MainActor
@Test("根路径带尾斜杠时根目录变化仍触发全量重建")
func rootChangeWithTrailingSlashStillTriggersFullRefresh() {
    let coordinator = FileTreeNSViewBridge.Coordinator()
    let view = RecordingRefreshView()
    // coordinator 下发的路径已标准化（无尾斜杠），项目路径可能带尾斜杠。
    let root = "/tmp/lumi-file-tree-root-refresh"

    coordinator.applyTargetedRefresh(
        token: 1,
        changedPaths: [root],
        projectRootPath: root + "/",
        to: view
    )

    #expect(view.fullRefreshCount == 1)
    #expect(view.reloadedURLs.isEmpty)
}

@MainActor
@Test("根目录与子目录同时变化时只做一次全量重建")
func rootAndSubdirectoryChangeTriggersSingleFullRefresh() {
    let coordinator = FileTreeNSViewBridge.Coordinator()
    let view = RecordingRefreshView()
    let root = "/tmp/lumi-file-tree-root-refresh"

    coordinator.applyTargetedRefresh(
        token: 1,
        changedPaths: [root, root + "/Sources"],
        projectRootPath: root,
        to: view
    )

    #expect(view.fullRefreshCount == 1)
    #expect(view.reloadedURLs.isEmpty)
}

@MainActor
@Test("仅子目录变化时保持精准 reload，不全量重建")
func subdirectoryOnlyChangeStaysTargeted() {
    let coordinator = FileTreeNSViewBridge.Coordinator()
    let view = RecordingRefreshView()
    let root = "/tmp/lumi-file-tree-root-refresh"
    let subdirectory = root + "/Sources"

    coordinator.applyTargetedRefresh(
        token: 1,
        changedPaths: [subdirectory],
        projectRootPath: root,
        to: view
    )

    #expect(view.fullRefreshCount == 0)
    #expect(view.reloadedURLs == [URL(fileURLWithPath: subdirectory)])
}

@MainActor
@Test("相同精准刷新令牌不会重复派发")
func repeatedTargetedRefreshTokenIsDeduplicated() {
    let coordinator = FileTreeNSViewBridge.Coordinator()
    let view = RecordingRefreshView()
    let root = "/tmp/lumi-file-tree-root-refresh"

    coordinator.applyTargetedRefresh(token: 1, changedPaths: [root], projectRootPath: root, to: view)
    coordinator.applyTargetedRefresh(token: 1, changedPaths: [root], projectRootPath: root, to: view)

    #expect(view.fullRefreshCount == 1)
}

@MainActor
@Test("空变化集合兜底全量刷新")
func emptyChangedPathsFallsBackToFullRefresh() {
    let coordinator = FileTreeNSViewBridge.Coordinator()
    let view = RecordingRefreshView()

    coordinator.applyTargetedRefresh(
        token: 1,
        changedPaths: [],
        projectRootPath: "/tmp/lumi-file-tree-root-refresh",
        to: view
    )

    #expect(view.fullRefreshCount == 1)
    #expect(view.reloadedURLs.isEmpty)
}

/// 生产链路端到端：watcher 命中根目录 → bridge 派发 → 数据源重建后
/// 根级新增文件出现在 items 中（issue #183 的期望结果）。
@MainActor
@Test("根目录外部新增文件经根刷新后出现在树中")
func rootLevelExternalAdditionAppearsAfterRootRefresh() async throws {
    let root = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        .appendingPathComponent("lumi-file-tree-root-e2e-\(UUID().uuidString)", isDirectory: true)
    let existingFile = root.appendingPathComponent("a.txt")
    let addedFile = root.appendingPathComponent("b.txt")

    let reader = MutableFileSystemReader(
        children: [root.path: [existingFile]],
        directories: [root.path]
    )
    let store = InMemoryExpandedPathStore()
    let dataSource = FileTreeDataSource(fileSystemReader: reader, expandedPathStore: store)
    let adapter = DataSourceRefreshAdapter(dataSource)

    dataSource.setProjectRoot(root.path)
    try await waitUntil(timeout: 2) {
        dataSource.fileItems.contains { $0.url == existingFile }
    }
    #expect(!dataSource.fileItems.contains { $0.url == addedFile })

    // 模拟外部新增文件后 watcher 命中根目录：coordinator 下发标准化根路径。
    reader.updateChildren(of: root, to: [existingFile, addedFile])
    let coordinator = FileTreeNSViewBridge.Coordinator()
    coordinator.applyTargetedRefresh(
        token: 1,
        changedPaths: [PathFormatter.normalizedFilePath(root)],
        projectRootPath: root.path,
        to: adapter
    )

    try await waitUntil(timeout: 2) {
        dataSource.fileItems.contains { $0.url == addedFile }
    }
    #expect(dataSource.fileItems.contains { $0.url == existingFile })
}

// MARK: - Test Doubles

@MainActor
private final class RecordingRefreshView: FileTreeRefreshing {
    private(set) var fullRefreshCount = 0
    private(set) var reloadedURLs: [URL] = []

    func fullRefresh() {
        fullRefreshCount += 1
    }

    func reloadDirectory(at url: URL) {
        reloadedURLs.append(url)
    }
}

@MainActor
private final class DataSourceRefreshAdapter: FileTreeRefreshing {
    private let dataSource: FileTreeDataSource

    init(_ dataSource: FileTreeDataSource) {
        self.dataSource = dataSource
    }

    func fullRefresh() {
        dataSource.fullRefresh()
    }

    func reloadDirectory(at url: URL) {
        dataSource.reloadDirectory(at: url)
    }
}

private final class MutableFileSystemReader: FileSystemReading, @unchecked Sendable {
    private let lock = NSLock()
    private var children: [String: [URL]]
    private let directories: Set<String>

    init(children: [String: [URL]], directories: Set<String>) {
        self.children = children
        self.directories = directories
    }

    func updateChildren(of url: URL, to urls: [URL]) {
        lock.lock()
        children[url.path] = urls
        lock.unlock()
    }

    func contentsOfDirectory(
        at url: URL,
        includingPropertiesForKeys keys: [URLResourceKey],
        options: FileManager.DirectoryEnumerationOptions
    ) throws -> [URL] {
        lock.lock()
        defer { lock.unlock() }
        guard let snapshot = children[url.path] else {
            throw CocoaError(.fileReadNoSuchFile)
        }
        return snapshot
    }

    func isDirectory(_ url: URL) -> Bool {
        directories.contains(url.path)
    }

    func fileExists(atPath path: String) -> Bool {
        false
    }

    func sortAndFilter(_ urls: [URL]) -> [URL] {
        urls
    }
}

private final class InMemoryExpandedPathStore: ExpandedPathStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var pathsByRoot: [String: Set<String>] = [:]

    func expandedPaths(for projectRoot: String) -> Set<String> {
        lock.lock()
        defer { lock.unlock() }
        return pathsByRoot[projectRoot] ?? []
    }

    func addExpandedPath(_ relativePath: String, for projectRoot: String) {
        lock.lock()
        pathsByRoot[projectRoot, default: []].insert(relativePath)
        lock.unlock()
    }

    func removeExpandedPath(_ relativePath: String, for projectRoot: String) {
        lock.lock()
        pathsByRoot[projectRoot]?.remove(relativePath)
        lock.unlock()
    }
}

@MainActor
private func waitUntil(
    timeout: TimeInterval,
    _ condition: () -> Bool
) async throws {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition() {
        guard Date() < deadline else {
            Issue.record("等待超时（\(timeout)s）：条件未满足")
            return
        }
        try await Task.sleep(nanoseconds: 10_000_000)
    }
}