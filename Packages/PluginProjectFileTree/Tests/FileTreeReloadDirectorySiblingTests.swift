import Foundation
import Testing

@testable import PluginProjectFileTree

/// 回归 #182：对某个已展开目录做精准刷新时，只能替换该目录及其子树，
/// 不能把扁平列表里排在它后面的兄弟目录/文件一并删除。
///
/// ## 历史 bug
///
/// `reloadDirectoryNow` 向后扫描子树时，遇到第一个深度不大于目标目录的
/// 兄弟节点，`default` 分支把 `endIndex` 设成 `items.count`，使替换范围
/// 一直延伸到列表末尾，导致该目录之后的所有兄弟节点被删除。
@MainActor
@Test("精准刷新目录不会删除其后的兄弟节点")
func reloadDirectoryKeepsFollowingSiblings() async throws {
    let root = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        .appendingPathComponent("lumi-file-tree-siblings-\(UUID().uuidString)", isDirectory: true)
    let dirA = root.appendingPathComponent("A", isDirectory: true)
    let dirB = root.appendingPathComponent("B", isDirectory: true)
    let tail = root.appendingPathComponent("tail.txt")
    let a1 = dirA.appendingPathComponent("a1.txt")
    let a2 = dirA.appendingPathComponent("a2.txt")
    let b1 = dirB.appendingPathComponent("b1.txt")

    let reader = SiblingStubFileSystemReader(
        children: [
            root.path: [dirA, dirB, tail],
            dirA.path: [a1],
            dirB.path: [b1],
        ],
        directories: [root.path, dirA.path, dirB.path]
    )
    let store = SiblingInMemoryExpandedPathStore()
    store.addExpandedPath("/A", for: root.path)
    store.addExpandedPath("/B", for: root.path)
    let dataSource = FileTreeDataSource(fileSystemReader: reader, expandedPathStore: store)

    dataSource.setProjectRoot(root.path)
    try await siblingWaitUntil(timeout: 2) {
        dataSource.fileItems.contains { $0.url == dirB }
            && dataSource.fileItems.contains { $0.url == tail }
            && dataSource.fileItems.contains { $0.url == a1 }
    }

    // A 内新增文件后触发精准刷新（rename/delete 成功后同样走这条路径）。
    reader.updateChildren(of: dirA, to: [a1, a2])
    dataSource.reloadDirectory(at: dirA)

    #expect(dataSource.fileItems.contains { $0.url == a2 }, "A 的新文件应出现")
    #expect(dataSource.fileItems.contains { $0.url == dirB }, "兄弟目录 B 不应被删除")
    #expect(dataSource.fileItems.contains { $0.url == b1 }, "B 的子节点不应被删除")
    #expect(dataSource.fileItems.contains { $0.url == tail }, "兄弟文件 tail.txt 不应被删除")
}

private final class SiblingStubFileSystemReader: FileSystemReading, @unchecked Sendable {
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

private final class SiblingInMemoryExpandedPathStore: ExpandedPathStoring, @unchecked Sendable {
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
private func siblingWaitUntil(
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