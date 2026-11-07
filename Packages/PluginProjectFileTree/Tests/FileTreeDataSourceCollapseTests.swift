import Foundation
import Testing

@testable import PluginProjectFileTree

/// 折叠父目录时必须同时清除后代的展开状态。
///
/// `expandedPaths` 存的是项目相对路径（如 `/src/Views`），旧实现却用绝对路径
/// 做前缀过滤，后代永远命中不了；重新展开父目录时旧子树会自动恢复展开，
/// 且残留路径会一直留在持久化存储里。
@MainActor
@Suite(.serialized)
struct FileTreeDataSourceCollapseTests {

    @Test("折叠父目录会清除后代的展开状态")
    func collapsingParentClearsDescendantExpansion() async {
        let fixture = makeFixture()
        let dataSource = fixture.dataSource

        dataSource.setProjectRoot(fixture.root.path)
        await waitUntil { dataSource.fileItems.contains { $0.url == fixture.srcURL } }

        dataSource.toggleExpansion(at: fixture.srcURL)
        await waitUntil { self.isExpanded(fixture.srcURL, in: dataSource) }

        dataSource.toggleExpansion(at: fixture.viewsURL)
        await waitUntil { self.isExpanded(fixture.viewsURL, in: dataSource) }
        #expect(fixture.store.contains("/src/Views", for: fixture.root.path))

        dataSource.toggleExpansion(at: fixture.srcURL)
        await waitUntil { !dataSource.fileItems.contains { $0.url == fixture.viewsURL } }

        // 内存与持久化状态都不能残留子目录。
        #expect(!fixture.store.contains("/src/Views", for: fixture.root.path))
        #expect(!fixture.store.contains("/src", for: fixture.root.path))

        dataSource.toggleExpansion(at: fixture.srcURL)
        await waitUntil { dataSource.fileItems.contains { $0.url == fixture.viewsURL } }

        // 重新展开父目录后，子目录保持折叠。
        #expect(!isExpanded(fixture.viewsURL, in: dataSource))
        #expect(fixture.store.contains("/src", for: fixture.root.path))
        #expect(!fixture.store.contains("/src/Views", for: fixture.root.path))
    }

    private func isExpanded(_ url: URL, in dataSource: FileTreeDataSource) -> Bool {
        dataSource.fileItems.first { $0.url == url }?.isExpanded == true
    }

    private func waitUntil(
        timeout: Duration = .seconds(2),
        _ condition: () -> Bool
    ) async {
        let deadline = ContinuousClock.now.advanced(by: timeout)
        while ContinuousClock.now < deadline {
            if condition() { return }
            try? await Task.sleep(for: .milliseconds(10))
        }
        #expect(condition())
    }

    private struct Fixture {
        let root: URL
        let srcURL: URL
        let viewsURL: URL
        let store: InMemoryExpandedPathStore
        let dataSource: FileTreeDataSource
    }

    private func makeFixture() -> Fixture {
        let root = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("lumi-file-tree-collapse-\(UUID().uuidString)", isDirectory: true)
        let src = root.appendingPathComponent("src", isDirectory: true)
        let views = src.appendingPathComponent("Views", isDirectory: true)

        let reader = MockFileSystemReader(
            children: [
                root.path: [
                    root.appendingPathComponent("README.md"),
                    src
                ],
                src.path: [
                    src.appendingPathComponent("main.swift"),
                    views
                ],
                views.path: [
                    views.appendingPathComponent("Foo.swift")
                ]
            ],
            directories: [root.path, src.path, views.path]
        )
        let store = InMemoryExpandedPathStore()
        let dataSource = FileTreeDataSource(fileSystemReader: reader, expandedPathStore: store)
        return Fixture(root: root, srcURL: src, viewsURL: views, store: store, dataSource: dataSource)
    }
}

private final class MockFileSystemReader: FileSystemReading, @unchecked Sendable {
    private let children: [String: [URL]]
    private let directories: Set<String>

    init(children: [String: [URL]], directories: Set<String>) {
        self.children = children
        self.directories = directories
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
        defer { lock.unlock() }
        pathsByRoot[projectRoot, default: []].insert(relativePath)
    }

    func removeExpandedPath(_ relativePath: String, for projectRoot: String) {
        lock.lock()
        defer { lock.unlock() }
        pathsByRoot[projectRoot]?.remove(relativePath)
    }

    func contains(_ relativePath: String, for projectRoot: String) -> Bool {
        expandedPaths(for: projectRoot).contains(relativePath)
    }
}
