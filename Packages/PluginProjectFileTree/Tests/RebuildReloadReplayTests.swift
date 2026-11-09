import Foundation
import Testing

@testable import PluginProjectFileTree

/// 回归 #1103：重建期间 watcher 已发布并被 bridge 消费的精准刷新，
/// 会因 items 已清空而在 `reloadDirectory` 处静默返回；遍历提交旧快照后
/// 外部新增文件永久缺失。
@MainActor
@Test("重建期间的精准刷新会在提交后重放")
func targetedReloadDuringRebuildIsReplayed() async throws {
    let root = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        .appendingPathComponent("lumi-file-tree-rebuild-\(UUID().uuidString)", isDirectory: true)
    let watchedDirectory = root.appendingPathComponent("D", isDirectory: true)
    let existingFile = watchedDirectory.appendingPathComponent("existing.txt")
    let addedFile = watchedDirectory.appendingPathComponent("new.txt")

    let reader = GatedFileSystemReader(
        children: [
            root.path: [watchedDirectory],
            watchedDirectory.path: [existingFile],
        ],
        directories: [root.path, watchedDirectory.path],
        gatedDirectoryPath: watchedDirectory.path
    )
    let store = InMemoryExpandedPathStore()
    store.addExpandedPath("/D", for: root.path)
    let dataSource = FileTreeDataSource(fileSystemReader: reader, expandedPathStore: store)

    dataSource.setProjectRoot(root.path)
    #expect(dataSource.fileItems.isEmpty)

    try await waitUntil(timeout: 2) { reader.gateReached }
    #expect(dataSource.fileItems.isEmpty)

    // 遍历已读过 D 的旧内容但尚未提交；此时 watcher 的变化目录被 bridge
    // 消费并调用 reload，当前实现会因空树直接返回。
    reader.updateChildren(of: watchedDirectory, to: [existingFile, addedFile])
    dataSource.reloadDirectory(at: watchedDirectory)
    #expect(dataSource.fileItems.isEmpty)

    reader.openGate()

    try await waitUntil(timeout: 2) {
        dataSource.fileItems.contains { $0.url == addedFile }
    }
    #expect(dataSource.fileItems.contains { $0.url == existingFile })
}

private final class GatedFileSystemReader: FileSystemReading, @unchecked Sendable {
    private let lock = NSLock()
    private var children: [String: [URL]]
    private let directories: Set<String>
    private let gatedDirectoryPath: String
    private var didGate = false
    private var reached = false
    private let gate = DispatchSemaphore(value: 0)

    init(children: [String: [URL]], directories: Set<String>, gatedDirectoryPath: String) {
        self.children = children
        self.directories = directories
        self.gatedDirectoryPath = gatedDirectoryPath
    }

    var gateReached: Bool {
        lock.lock()
        defer { lock.unlock() }
        return reached
    }

    func updateChildren(of url: URL, to urls: [URL]) {
        lock.lock()
        children[url.path] = urls
        lock.unlock()
    }

    func openGate() {
        gate.signal()
    }

    func contentsOfDirectory(
        at url: URL,
        includingPropertiesForKeys keys: [URLResourceKey],
        options: FileManager.DirectoryEnumerationOptions
    ) throws -> [URL] {
        lock.lock()
        guard let snapshot = children[url.path] else {
            lock.unlock()
            throw CocoaError(.fileReadNoSuchFile)
        }
        let shouldGate = !didGate && url.path == gatedDirectoryPath
        if shouldGate {
            didGate = true
            reached = true
        }
        lock.unlock()

        if shouldGate {
            gate.wait()
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
