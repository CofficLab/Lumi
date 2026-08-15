import Testing
import Foundation
@testable import FileSystemKit

@Suite("FileTreeStore Tests")
struct FileTreeStoreTests {

    // MARK: - Helper

    /// 创建基于临时目录的 FileTreeStore
    private func makeStore() throws -> FileTreeStore {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileTreeKitTest-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return FileTreeStore(directory: tempDir)
    }

    // MARK: - Basic get/set

    @Test("set and object round-trip for string")
    func setAndGetString() throws {
        let store = try makeStore()
        store.set("hello", forKey: "greeting")
        #expect(store.string(forKey: "greeting") == "hello")
    }

    @Test("set and object round-trip for array")
    func setAndGetArray() throws {
        let store = try makeStore()
        store.set(["a", "b", "c"], forKey: "letters")
        let result = store.object(forKey: "letters") as? [String]
        #expect(result == ["a", "b", "c"])
    }

    @Test("set nil removes key")
    func setNilRemovesKey() throws {
        let store = try makeStore()
        store.set("value", forKey: "key")
        #expect(store.string(forKey: "key") != nil)

        store.set(nil, forKey: "key")
        #expect(store.string(forKey: "key") == nil)
    }

    @Test("object returns nil for nonexistent key")
    func objectReturnsNilForMissingKey() throws {
        let store = try makeStore()
        #expect(store.object(forKey: "nonexistent") == nil)
    }

    @Test("string returns nil for non-string value")
    func stringReturnsNilForNonString() throws {
        let store = try makeStore()
        store.set(42, forKey: "number")
        #expect(store.string(forKey: "number") == nil)
    }

    // MARK: - Expanded Paths

    @Test("expandedPaths returns empty for new project")
    func expandedPathsEmptyForNewProject() throws {
        let store = try makeStore()
        let paths = store.expandedPaths(for: "/path/to/project")
        #expect(paths.isEmpty)
    }

    @Test("setExpandedPaths and expandedPaths round-trip")
    func setAndGetExpandedPaths() throws {
        let store = try makeStore()
        let expected: Set<String> = ["/src", "/lib", "/tests"]
        store.setExpandedPaths(expected, for: "/path/to/project")
        let result = store.expandedPaths(for: "/path/to/project")
        #expect(result == expected)
    }

    @Test("expandedPaths are isolated per project")
    func expandedPathsIsolatedPerProject() throws {
        let store = try makeStore()
        store.setExpandedPaths(["/a"], for: "/project1")
        store.setExpandedPaths(["/b"], for: "/project2")

        #expect(store.expandedPaths(for: "/project1") == ["/a"])
        #expect(store.expandedPaths(for: "/project2") == ["/b"])
    }

    @Test("addExpandedPath adds path to existing set")
    func addExpandedPath() throws {
        let store = try makeStore()
        store.setExpandedPaths(["/src"], for: "/project")
        store.addExpandedPath("/lib", for: "/project")

        let result = store.expandedPaths(for: "/project")
        #expect(result == ["/src", "/lib"])
    }

    @Test("addExpandedPath deduplicates")
    func addExpandedPathDeduplicates() throws {
        let store = try makeStore()
        store.setExpandedPaths(["/src"], for: "/project")
        store.addExpandedPath("/src", for: "/project")

        let result = store.expandedPaths(for: "/project")
        #expect(result == ["/src"])
    }

    @Test("addExpandedPath works on empty store")
    func addExpandedPathEmptyStore() throws {
        let store = try makeStore()
        store.addExpandedPath("/src", for: "/project")
        #expect(store.expandedPaths(for: "/project") == ["/src"])
    }

    @Test("removeExpandedPath removes path from set")
    func removeExpandedPath() throws {
        let store = try makeStore()
        store.setExpandedPaths(["/src", "/lib", "/tests"], for: "/project")
        store.removeExpandedPath("/lib", for: "/project")

        let result = store.expandedPaths(for: "/project")
        #expect(result == ["/src", "/tests"])
    }

    @Test("removeExpandedPath handles nonexistent path gracefully")
    func removeExpandedPathNonexistent() throws {
        let store = try makeStore()
        store.setExpandedPaths(["/src"], for: "/project")
        store.removeExpandedPath("/nonexistent", for: "/project")

        let result = store.expandedPaths(for: "/project")
        #expect(result == ["/src"])
    }

    // MARK: - Last Project Path

    @Test("lastProjectPath returns nil initially")
    func lastProjectPathNilInitially() throws {
        let store = try makeStore()
        #expect(store.lastProjectPath() == nil)
    }

    @Test("setLastProjectPath and lastProjectPath round-trip")
    func setAndGetLastProjectPath() throws {
        let store = try makeStore()
        store.setLastProjectPath("/path/to/project")
        #expect(store.lastProjectPath() == "/path/to/project")
    }

    @Test("setLastProjectPath overwrites previous value")
    func setLastProjectPathOverwrites() throws {
        let store = try makeStore()
        store.setLastProjectPath("/old/project")
        store.setLastProjectPath("/new/project")
        #expect(store.lastProjectPath() == "/new/project")
    }

    // MARK: - Persistence

    @Test("data persists across store instances")
    func dataPersistsAcrossInstances() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileTreeKitTest-Persist-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let store1 = FileTreeStore(directory: tempDir)
        store1.setExpandedPaths(["/src", "/lib"], for: "/project")
        store1.setLastProjectPath("/project")

        // 创建新的 store 实例，指向同一个目录
        let store2 = FileTreeStore(directory: tempDir)
        #expect(store2.expandedPaths(for: "/project") == ["/src", "/lib"])
        #expect(store2.lastProjectPath() == "/project")
    }

    @Test("set quarantines invalid settings file and recovers")
    func setQuarantinesInvalidSettingsFileAndRecovers() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileTreeKitTest-Invalid-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let settingsURL = tempDir.appendingPathComponent("settings.plist")
        let corruptURL = tempDir.appendingPathComponent("settings.corrupt.plist")
        let invalidData = Data("not a plist".utf8)
        try invalidData.write(to: settingsURL)

        let store = FileTreeStore(directory: tempDir)

        #expect(store.setLastProjectPath("/project") == true)
        #expect((try? Data(contentsOf: corruptURL)) == invalidData)
        #expect(store.lastProjectPath() == "/project")

        let reloadedStore = FileTreeStore(directory: tempDir)
        #expect(reloadedStore.lastProjectPath() == "/project")
    }

    @Test("non-dictionary plist root is quarantined and reads return empty")
    func nonDictionaryPlistRootIsQuarantined() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileTreeKitTest-NonDict-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let settingsURL = tempDir.appendingPathComponent("settings.plist")
        let corruptURL = tempDir.appendingPathComponent("settings.corrupt.plist")
        let arrayPlistData = try PropertyListSerialization.data(
            fromPropertyList: ["not", "a", "dictionary"],
            format: .binary,
            options: 0
        )
        try arrayPlistData.write(to: settingsURL)

        let store = FileTreeStore(directory: tempDir)

        // 根节点不是字典：读取返回空，原文件被隔离
        #expect(store.object(forKey: "any") == nil)
        #expect(FileManager.default.fileExists(atPath: corruptURL.path))
        #expect((try? Data(contentsOf: corruptURL)) == arrayPlistData)

        // 隔离后可正常写入与读取
        #expect(store.setLastProjectPath("/project") == true)
        #expect(store.lastProjectPath() == "/project")
    }

    @Test("flushDirtyCache persists debounced changes immediately")
    func flushDirtyCachePersistsDebouncedChanges() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileTreeKitTest-Flush-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let store = FileTreeStore(directory: tempDir)
        #expect(store.addExpandedPath("/src", for: "/project"))

        // 防抖间隔内，新实例从磁盘读取应看不到未落盘的变更
        let beforeFlush = FileTreeStore(directory: tempDir)
        #expect(beforeFlush.expandedPaths(for: "/project").isEmpty)

        // flush 后立即落盘，新实例可见
        store.flushDirtyCache()
        let afterFlush = FileTreeStore(directory: tempDir)
        #expect(afterFlush.expandedPaths(for: "/project") == ["/src"])

        // 无脏数据时 flush 不应崩溃或产生副作用
        store.flushDirtyCache()
        #expect(afterFlush.expandedPaths(for: "/project") == ["/src"])
    }

    @Test("pending debounced changes are persisted on deinit")
    func debouncedChangesPersistOnDeinit() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileTreeKitTest-Deinit-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let storeBox = FileTreeStoreBox(FileTreeStore(directory: tempDir))
        #expect(storeBox.store!.addExpandedPath("/src", for: "/project"))
        #expect(storeBox.store!.addExpandedPath("/lib", for: "/project"))

        // 释放实例触发 deinit 同步落盘
        storeBox.release()

        let reloaded = FileTreeStore(directory: tempDir)
        #expect(reloaded.expandedPaths(for: "/project") == ["/src", "/lib"])
    }

    /// 用于在测试作用域内显式释放 FileTreeStore，触发 deinit
    private final class FileTreeStoreBox {
        var store: FileTreeStore?
        init(_ store: FileTreeStore) { self.store = store }
        func release() { store = nil }
    }

    @Test("set reports failure when settings directory is blocked")
    func setReportsFailureWhenSettingsDirectoryIsBlocked() throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileTreeKitTest-Blocked-\(UUID().uuidString)", isDirectory: true)
        let blockedDirectory = tempRoot.appendingPathComponent("FileTreeSettings", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        try "not a directory".write(to: blockedDirectory, atomically: true, encoding: .utf8)

        let store = FileTreeStore(directory: blockedDirectory)

        #expect(store.setExpandedPaths(["/src"], for: "/project") == false)
        #expect(store.expandedPaths(for: "/project").isEmpty)
    }

    // MARK: - Key Sanitization

    @Test("project roots with special characters are handled correctly")
    func projectRootSpecialCharacters() throws {
        let store = try makeStore()
        let projectRoot = "/Users/test/my project (v2)"
        store.setExpandedPaths(["/src"], for: projectRoot)
        #expect(store.expandedPaths(for: projectRoot) == ["/src"])
    }

    @Test("different project roots with similar names are isolated")
    func similarProjectRootsIsolated() throws {
        let store = try makeStore()
        store.setExpandedPaths(["/a"], for: "/project")
        store.setExpandedPaths(["/b"], for: "/project-v2")
        store.setExpandedPaths(["/c"], for: "/project_v2")

        #expect(store.expandedPaths(for: "/project") == ["/a"])
        #expect(store.expandedPaths(for: "/project-v2") == ["/b"])
        #expect(store.expandedPaths(for: "/project_v2") == ["/c"])
    }

    // MARK: - Overwrite / Replace Branch

    @Test("set overwrites existing value in same store instance")
    func setOverwritesExistingValue() throws {
        let store = try makeStore()
        store.set("first", forKey: "key")
        #expect(store.string(forKey: "key") == "first")

        // 第二次写入同 key，覆盖旧值 → 内部走 replaceItemAt 分支
        store.set("second", forKey: "key")
        #expect(store.string(forKey: "key") == "second")
    }

    @Test("expandedPaths overwrites previous set for same project")
    func expandedPathsOverwritesPrevious() throws {
        let store = try makeStore()
        store.setExpandedPaths(["/a", "/b"], for: "/project")
        #expect(store.expandedPaths(for: "/project") == ["/a", "/b"])

        // 覆盖写入 → 内部走 replaceItemAt 分支
        store.setExpandedPaths(["/c"], for: "/project")
        #expect(store.expandedPaths(for: "/project") == ["/c"])
    }

    // MARK: - Thread Safety

    @Test("concurrent reads and writes do not crash")
    func concurrentAccessSafety() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileTreeKitTest-Concurrent-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let store = FileTreeStore(directory: tempDir)

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<50 {
                group.addTask {
                    store.setExpandedPaths(["/path\(i)"], for: "/project\(i % 5)")
                }
                group.addTask {
                    _ = store.expandedPaths(for: "/project\(i % 5)")
                }
                group.addTask {
                    store.setLastProjectPath("/project\(i % 5)")
                }
            }
        }

        // 只要没崩溃就算通过
        let paths = store.expandedPaths(for: "/project0")
        #expect(!paths.isEmpty || store.lastProjectPath() != nil)
    }
}
