import Testing
import Foundation
@testable import FileTreeKit

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
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let store1 = FileTreeStore(directory: tempDir)
        store1.setExpandedPaths(["/src", "/lib"], for: "/project")
        store1.setLastProjectPath("/project")

        // 创建新的 store 实例，指向同一个目录
        let store2 = FileTreeStore(directory: tempDir)
        #expect(store2.expandedPaths(for: "/project") == ["/src", "/lib"])
        #expect(store2.lastProjectPath() == "/project")
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
}
