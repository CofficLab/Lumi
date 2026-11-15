import Foundation
import Testing

@testable import PluginProjectFileTree

/// 回归 #1235：watcher 一次下发 K 个变化目录时，旧实现在主线程逐个同步执行
/// `expandDirectory`（磁盘枚举 + 每个目录节点的 `Package.swift` 探测），
/// 并且每个目录都提交一次列表，K 个目录就是 K 次全量 diff。
///
/// 期望：枚举全部在后台线程、嵌套/重复路径合并、K 个结果只提交一次列表。
///
/// 门闩会阻塞协作线程池里的线程，必须串行执行，否则多个用例同时阻塞会把池耗尽。
@MainActor
@Suite("精准刷新后台扫描", .serialized)
struct FileTreeTargetedReloadOffMainTests {

    @Test("目录枚举与节点构造都不在主线程执行")
    func enumerationRunsOffMainThread() async throws {
        let fixture = Fixture.make(
            children: { root, dirA, fileA in [root.path: [dirA], dirA.path: [fileA]] },
            expanded: ["/A"]
        )
        try await fixture.waitUntilBuilt()
        fixture.reader.resetThreadFlags()

        let added = fixture.dirA.appendingPathComponent("added.txt")
        fixture.reader.updateChildren(of: fixture.dirA, to: [fixture.fileA, added])
        fixture.dataSource.reloadDirectory(at: fixture.dirA)
        try await fixture.waitUntil { fixture.dataSource.fileItems.contains { $0.url == added } }

        #expect(fixture.reader.sawMainThreadEnumeration == false, "目录枚举不能在主线程执行")
        #expect(fixture.reader.sawMainThreadFileExists == false, "节点的 Package.swift 探测不能在主线程执行")
    }

    @Test("扫描期间主线程仍可响应，且旧列表保留到新结果就绪")
    func mainActorStaysResponsiveWhileScanning() async throws {
        let fixture = Fixture.make(
            children: { root, dirA, fileA in [root.path: [dirA], dirA.path: [fileA]] },
            expanded: ["/A"]
        )
        fixture.reader.gatedPath = fixture.dirA.path
        try await fixture.waitUntilBuilt()

        let added = fixture.dirA.appendingPathComponent("added.txt")
        fixture.reader.updateChildren(of: fixture.dirA, to: [fixture.fileA, added])
        fixture.reader.armGate()
        fixture.dataSource.reloadDirectory(at: fixture.dirA)

        // 门闩未打开时扫描仍在后台阻塞：主线程能继续跑到这里，说明没有被同步 I/O 卡住。
        try await fixture.waitUntil { fixture.reader.gateReached }
        #expect(!fixture.dataSource.fileItems.contains { $0.url == added })
        #expect(fixture.dataSource.fileItems.contains { $0.url == fixture.fileA })

        fixture.reader.openGate()
        try await fixture.waitUntil { fixture.dataSource.fileItems.contains { $0.url == added } }
    }

    @Test("嵌套与重复目录合并成一轮扫描")
    func nestedAndDuplicatePathsAreCoalesced() async throws {
        let fixture = Fixture.make(
            children: { root, dirA, fileA in
                [
                    root.path: [dirA, dirB(root)],
                    dirA.path: [subDirectory(dirA)],
                    subDirectory(dirA).path: [fileA],
                    dirB(root).path: [],
                ]
            },
            expanded: ["/A", "/A/Sub", "/B"]
        )
        try await fixture.waitUntilBuilt()
        fixture.reader.resetEnumerationCounts()

        let sub = subDirectory(fixture.dirA)
        let dirBURL = dirB(fixture.root)
        fixture.dataSource.reloadDirectories(at: [fixture.dirA, sub, fixture.dirA, dirBURL])
        try await fixture.waitUntil { fixture.reader.enumerationCount(for: dirBURL) >= 1 }

        #expect(fixture.reader.enumerationCount(for: fixture.dirA) == 1, "重复目录只扫一次")
        #expect(fixture.reader.enumerationCount(for: sub) == 1, "嵌套子目录随父目录一起扫，不单独再扫一遍")
        #expect(fixture.reader.enumerationCount(for: fixture.root) == 0, "精准刷新不应重扫根目录")
    }

    @Test("K 个目录的结果只提交一次列表更新")
    func batchCommitsItemsOnce() async throws {
        let fixture = Fixture.make(
            children: { root, dirA, fileA in
                [
                    root.path: [dirA, dirB(root), dirC(root)],
                    dirA.path: [fileA],
                    dirB(root).path: [],
                    dirC(root).path: [],
                ]
            },
            expanded: ["/A", "/B", "/C"]
        )
        try await fixture.waitUntilBuilt()
        fixture.resetChangeCount()

        let dirBURL = dirB(fixture.root)
        let dirCURL = dirC(fixture.root)
        let addedA = fixture.dirA.appendingPathComponent("a-new.txt")
        let addedB = dirBURL.appendingPathComponent("b-new.txt")
        let addedC = dirCURL.appendingPathComponent("c-new.txt")
        fixture.reader.updateChildren(of: fixture.dirA, to: [fixture.fileA, addedA])
        fixture.reader.updateChildren(of: dirBURL, to: [addedB])
        fixture.reader.updateChildren(of: dirCURL, to: [addedC])

        fixture.dataSource.reloadDirectories(at: [fixture.dirA, dirBURL, dirCURL])
        try await fixture.waitUntil { fixture.dataSource.fileItems.contains { $0.url == addedC } }

        #expect(fixture.dataSource.fileItems.contains { $0.url == addedA })
        #expect(fixture.dataSource.fileItems.contains { $0.url == addedB })
        #expect(fixture.changeCount == 1, "三个目录的结果必须合并成一次列表提交")
    }

    @Test("在途扫描期间新到的目录不会被丢掉")
    func directoriesArrivingDuringScanAreNotLost() async throws {
        let fixture = Fixture.make(
            children: { root, dirA, fileA in
                [root.path: [dirA, dirB(root)], dirA.path: [fileA], dirB(root).path: []]
            },
            expanded: ["/A", "/B"]
        )
        fixture.reader.gatedPath = fixture.dirA.path
        try await fixture.waitUntilBuilt()

        let dirBURL = dirB(fixture.root)
        let addedA = fixture.dirA.appendingPathComponent("a-new.txt")
        let addedB = dirBURL.appendingPathComponent("b-new.txt")
        fixture.reader.updateChildren(of: fixture.dirA, to: [fixture.fileA, addedA])
        fixture.reader.updateChildren(of: dirBURL, to: [addedB])

        fixture.reader.armGate()
        fixture.dataSource.reloadDirectory(at: fixture.dirA)
        try await fixture.waitUntil { fixture.reader.gateReached }

        // A 的扫描仍在途时 B 也发生变化：不能因为合并/取消而丢掉 B 的刷新。
        fixture.dataSource.reloadDirectory(at: dirBURL)
        fixture.reader.openGate()

        try await fixture.waitUntil {
            fixture.dataSource.fileItems.contains { $0.url == addedA }
                && fixture.dataSource.fileItems.contains { $0.url == addedB }
        }
    }

    @Test("切换项目后晚到的旧扫描结果不覆盖新项目的树")
    func staleScanDoesNotOverwriteNewProject() async throws {
        let fixture = Fixture.make(
            children: { root, dirA, fileA in [root.path: [dirA], dirA.path: [fileA]] },
            expanded: ["/A"]
        )
        fixture.reader.gatedPath = fixture.dirA.path
        try await fixture.waitUntilBuilt()

        let otherRoot = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("lumi-file-tree-other-\(UUID().uuidString)", isDirectory: true)
        let otherFile = otherRoot.appendingPathComponent("other.txt")
        fixture.reader.updateChildren(of: otherRoot, to: [otherFile])
        fixture.reader.markDirectory(otherRoot)

        let added = fixture.dirA.appendingPathComponent("added.txt")
        fixture.reader.updateChildren(of: fixture.dirA, to: [fixture.fileA, added])
        fixture.reader.armGate()
        fixture.dataSource.reloadDirectory(at: fixture.dirA)
        try await fixture.waitUntil { fixture.reader.gateReached }

        fixture.dataSource.setProjectRoot(otherRoot.path)
        try await fixture.waitUntil { fixture.dataSource.fileItems.contains { $0.url == otherFile } }

        fixture.reader.openGate()
        try await Task.sleep(nanoseconds: 150_000_000)

        #expect(fixture.dataSource.projectRootPath == otherRoot.path)
        #expect(!fixture.dataSource.fileItems.contains { $0.url == fixture.dirA }, "旧项目的扫描结果必须被丢弃")
        #expect(!fixture.dataSource.fileItems.contains { $0.url == added })
        #expect(fixture.dataSource.fileItems.contains { $0.url == otherFile })
    }
}

// MARK: - 路径辅助

private func dirB(_ root: URL) -> URL {
    root.appendingPathComponent("B", isDirectory: true)
}

private func dirC(_ root: URL) -> URL {
    root.appendingPathComponent("C", isDirectory: true)
}

private func subDirectory(_ dirA: URL) -> URL {
    dirA.appendingPathComponent("Sub", isDirectory: true)
}

// MARK: - Fixture

@MainActor
private final class Fixture {
    let root: URL
    let dirA: URL
    let fileA: URL
    let reader: RecordingFileSystemReader
    let dataSource: FileTreeDataSource
    private(set) var changeCount = 0

    init(
        root: URL,
        dirA: URL,
        fileA: URL,
        reader: RecordingFileSystemReader,
        dataSource: FileTreeDataSource
    ) {
        self.root = root
        self.dirA = dirA
        self.fileA = fileA
        self.reader = reader
        self.dataSource = dataSource
        dataSource.onItemsChanged = { [weak self] _ in self?.changeCount += 1 }
    }

    static func make(
        children: (URL, URL, URL) -> [String: [URL]],
        expanded: [String]
    ) -> Fixture {
        let root = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("lumi-file-tree-targeted-\(UUID().uuidString)", isDirectory: true)
        let dirA = root.appendingPathComponent("A", isDirectory: true)
        let fileA = dirA.appendingPathComponent("a.txt")

        let contents = children(root, dirA, fileA)
        let reader = RecordingFileSystemReader(
            children: contents,
            directories: Set(contents.keys)
        )
        let store = InMemoryExpandedPathStore()
        for path in expanded {
            store.addExpandedPath(path, for: root.path)
        }
        let fixture = Fixture(
            root: root,
            dirA: dirA,
            fileA: fileA,
            reader: reader,
            dataSource: FileTreeDataSource(fileSystemReader: reader, expandedPathStore: store)
        )
        fixture.dataSource.setProjectRoot(root.path)
        return fixture
    }

    func resetChangeCount() {
        changeCount = 0
    }

    func waitUntilBuilt() async throws {
        try await waitUntil { dataSource.fileItems.contains { $0.url == dirA } }
    }

    func waitUntil(timeout: TimeInterval = 2, _ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            guard Date() < deadline else {
                Issue.record("等待超时（\(timeout)s）：条件未满足")
                return
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
    }
}

// MARK: - Test Doubles

private final class RecordingFileSystemReader: FileSystemReading, @unchecked Sendable {
    private let lock = NSLock()
    private var children: [String: [URL]]
    private var directories: Set<String>
    private var enumerationCounts: [String: Int] = [:]
    private var mainThreadEnumeration = false
    private var mainThreadFileExists = false
    private var didGate = false
    private var reached = false
    private var armed = false
    private let gate = DispatchSemaphore(value: 0)

    /// 需要门闩阻塞的目录路径；nil 表示不阻塞。
    var gatedPath: String?

    init(children: [String: [URL]], directories: Set<String>) {
        self.children = children
        self.directories = directories
    }

    var sawMainThreadEnumeration: Bool {
        lock.lock(); defer { lock.unlock() }
        return mainThreadEnumeration
    }

    var sawMainThreadFileExists: Bool {
        lock.lock(); defer { lock.unlock() }
        return mainThreadFileExists
    }

    var gateReached: Bool {
        lock.lock(); defer { lock.unlock() }
        return reached
    }

    func enumerationCount(for url: URL) -> Int {
        lock.lock(); defer { lock.unlock() }
        return enumerationCounts[url.path] ?? 0
    }

    func resetEnumerationCounts() {
        lock.lock(); defer { lock.unlock() }
        enumerationCounts.removeAll()
    }

    func resetThreadFlags() {
        lock.lock(); defer { lock.unlock() }
        mainThreadEnumeration = false
        mainThreadFileExists = false
    }

    func updateChildren(of url: URL, to urls: [URL]) {
        lock.lock(); defer { lock.unlock() }
        children[url.path] = urls
    }

    func markDirectory(_ url: URL) {
        lock.lock(); defer { lock.unlock() }
        directories.insert(url.path)
    }

    /// 让下一次命中 `gatedPath` 的枚举阻塞，直到 `openGate()`。
    func armGate() {
        lock.lock(); defer { lock.unlock() }
        armed = true
        didGate = false
        reached = false
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
        if Thread.isMainThread { mainThreadEnumeration = true }
        enumerationCounts[url.path, default: 0] += 1
        guard let snapshot = children[url.path] else {
            lock.unlock()
            throw CocoaError(.fileReadNoSuchFile)
        }
        let shouldGate = armed && !didGate && url.path == gatedPath
        if shouldGate {
            didGate = true
            reached = true
        }
        lock.unlock()

        if shouldGate { gate.wait() }
        return snapshot
    }

    func isDirectory(_ url: URL) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return directories.contains(url.path)
    }

    func fileExists(atPath path: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        if Thread.isMainThread { mainThreadFileExists = true }
        return false
    }

    func sortAndFilter(_ urls: [URL]) -> [URL] {
        urls
    }
}

private final class InMemoryExpandedPathStore: ExpandedPathStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var pathsByRoot: [String: Set<String>] = [:]

    func expandedPaths(for projectRoot: String) -> Set<String> {
        lock.lock(); defer { lock.unlock() }
        return pathsByRoot[projectRoot] ?? []
    }

    func addExpandedPath(_ relativePath: String, for projectRoot: String) {
        lock.lock(); defer { lock.unlock() }
        pathsByRoot[projectRoot, default: []].insert(relativePath)
    }

    func removeExpandedPath(_ relativePath: String, for projectRoot: String) {
        lock.lock(); defer { lock.unlock() }
        pathsByRoot[projectRoot]?.remove(relativePath)
    }
}