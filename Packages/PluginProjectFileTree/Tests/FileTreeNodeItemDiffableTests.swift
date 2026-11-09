import Foundation
import Testing

@testable import PluginProjectFileTree

/// 回归 #1104：`FileTreeNodeItem` 的相等性是 NSDiffableDataSource 判断是否
/// 重配置 cell 的依据。旧实现只比较 URL、depth、isExpanded，同一路径的普通文件
/// 被替换成同名目录时标识符被判定未变化，界面继续显示旧文件类型。
@MainActor
@Test("同一路径的文件与目录具有不同身份")
func samePathFileAndDirectoryHaveDistinctIdentity() {
    let root = URL(fileURLWithPath: "/tmp/lumi-identity", isDirectory: true)
    let entry = root.appendingPathComponent("entry")
    let reader = StubFileSystemReader(
        children: [root.path: [entry]],
        directories: [root.path]
    )

    let fileNode = FileTreeNodeItem(
        url: entry, depth: 1, isDirectory: false,
        isExpanded: false, projectRootPath: root.path,
        fileSystemReader: reader
    )
    let directoryNode = FileTreeNodeItem(
        url: entry, depth: 1, isDirectory: true,
        isExpanded: false, projectRootPath: root.path,
        fileSystemReader: reader
    )

    #expect(fileNode != directoryNode)
    #expect(Set([fileNode, directoryNode]).count == 2)
}

@MainActor
@Test("同一路径变为 Swift Package 目录后图标身份随之更新")
func swiftPackageMetadataChangesIdentity() {
    let root = URL(fileURLWithPath: "/tmp/lumi-identity", isDirectory: true)
    let entry = root.appendingPathComponent("Package")
    let plainReader = StubFileSystemReader(
        children: [root.path: [entry]],
        directories: [root.path, entry.path]
    )
    let packageReader = StubFileSystemReader(
        children: [root.path: [entry]],
        directories: [root.path, entry.path],
        packagePaths: [entry.appendingPathComponent("Package.swift").path]
    )

    let plainDirectory = FileTreeNodeItem(
        url: entry, depth: 1, isDirectory: true,
        isExpanded: false, projectRootPath: root.path,
        fileSystemReader: plainReader
    )
    let packageDirectory = FileTreeNodeItem(
        url: entry, depth: 1, isDirectory: true,
        isExpanded: false, projectRootPath: root.path,
        fileSystemReader: packageReader
    )

    #expect(plainDirectory.iconMetadata.isSwiftPackageDirectory == false)
    #expect(packageDirectory.iconMetadata.isSwiftPackageDirectory)
    #expect(plainDirectory != packageDirectory)
}

/// 数据源在外部把文件替换成同名目录后必须产出可被 diffable 识别为变化的新节点。
@MainActor
@Test("外部替换文件类型后精准刷新会更新节点身份")
func reloadedNodeIdentityFollowsFileTypeSwap() async throws {
    let root = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        .appendingPathComponent("lumi-file-tree-identity-\(UUID().uuidString)", isDirectory: true)
    let entry = root.appendingPathComponent("entry")

    let reader = StubFileSystemReader(
        children: [root.path: [entry]],
        directories: [root.path]
    )
    let dataSource = FileTreeDataSource(
        fileSystemReader: reader,
        expandedPathStore: InMemoryExpandedPathStore()
    )
    dataSource.setProjectRoot(root.path)

    try await waitUntil { dataSource.fileItems.contains { $0.url == entry } }
    let fileNode = try #require(dataSource.fileItems.first { $0.url == entry })
    #expect(!fileNode.isDirectory)

    reader.markDirectory(entry)
    dataSource.reloadDirectory(at: URL(fileURLWithPath: root.path))

    try await waitUntil {
        dataSource.fileItems.first { $0.url == entry }?.isDirectory == true
    }
    let directoryNode = try #require(dataSource.fileItems.first { $0.url == entry })
    #expect(directoryNode.isDirectory)
    #expect(directoryNode != fileNode)
}

private final class StubFileSystemReader: FileSystemReading, @unchecked Sendable {
    private let lock = NSLock()
    private let children: [String: [URL]]
    private var directories: Set<String>
    private let packagePaths: Set<String>

    init(
        children: [String: [URL]],
        directories: Set<String>,
        packagePaths: Set<String> = []
    ) {
        self.children = children
        self.directories = directories
        self.packagePaths = packagePaths
    }

    func markDirectory(_ url: URL) {
        lock.lock()
        directories.insert(url.path)
        lock.unlock()
    }

    func contentsOfDirectory(
        at url: URL,
        includingPropertiesForKeys keys: [URLResourceKey],
        options: FileManager.DirectoryEnumerationOptions
    ) throws -> [URL] {
        guard let children = children[url.path] else {
            throw CocoaError(.fileReadNoSuchFile)
        }
        return children
    }

    func isDirectory(_ url: URL) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return directories.contains(url.path)
    }

    func fileExists(atPath path: String) -> Bool {
        packagePaths.contains(path)
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
        defer { lock.unlock() }
        pathsByRoot[projectRoot, default: []].insert(relativePath)
    }

    func removeExpandedPath(_ relativePath: String, for projectRoot: String) {
        lock.lock()
        defer { lock.unlock() }
        pathsByRoot[projectRoot]?.remove(relativePath)
    }
}

@MainActor
private func waitUntil(
    timeout: TimeInterval = 2,
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
