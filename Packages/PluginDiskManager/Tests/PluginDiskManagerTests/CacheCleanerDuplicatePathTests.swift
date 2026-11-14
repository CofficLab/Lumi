import Foundation
import Testing
@testable import PluginDiskManager

/// 回归 #225：「应用缓存」展开 ~/Library/Caches 子项时会列出 Firefox/Safari，
/// 「浏览器缓存」又显式列出同一路径；默认全选后同一路径被删两次，第二次
/// removeItem 抛 NSFileNoSuchFileError，整个清理被中断、后续项不再处理。
@Suite("CacheCleanerDuplicatePath")
struct CacheCleanerDuplicatePathTests {

    private func makeTempRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("disk-dedup-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func makeDir(_ root: URL, _ name: String, bytes: Int) throws -> URL {
        let dir = root.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data(repeating: 0x41, count: bytes).write(to: dir.appendingPathComponent("cache.bin"))
        return dir
    }

    private func cachePath(_ url: URL, size: Int64) -> CachePath {
        CachePath(path: url.path, name: url.lastPathComponent, description: "", size: size, fileCount: 1, canDelete: true)
    }

    @Test("相同路径来自两个分类时只删一次、只计一次释放空间，并继续处理后续项")
    func cleanupDeduplicatesIdenticalPathsAndProcessesRest() async throws {
        let root = try makeTempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let firefox = try makeDir(root, "Firefox", bytes: 128)
        let safari = try makeDir(root, "Safari", bytes: 64)

        // App Cache 与 Browser Cache 各列出一次同一路径（不同 UUID）。
        let paths = [
            cachePath(firefox, size: 128),
            cachePath(firefox, size: 128),
            cachePath(safari, size: 64),
        ]

        let freed = try await CacheCleanerService.shared.cleanup(paths: paths)

        #expect(freed == 128 + 64, "Firefox 只应计入一次")
        #expect(!FileManager.default.fileExists(atPath: firefox.path))
        #expect(!FileManager.default.fileExists(atPath: safari.path), "重复项之后的 Safari 仍须被清理")
    }

    @Test("UI 清理遇到已不存在的路径时跳过而不中断后续项")
    func cleanupToleratesAlreadyMissingPath() async throws {
        let root = try makeTempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let valid = try makeDir(root, "Valid", bytes: 256)
        let missing = root.appendingPathComponent("DoesNotExist", isDirectory: true)

        let paths = [cachePath(missing, size: 0), cachePath(valid, size: 256)]

        let freed = try await CacheCleanerService.shared.cleanup(paths: paths, toleratingMissing: true)

        #expect(freed == 256)
        #expect(!FileManager.default.fileExists(atPath: valid.path), "缺失项之后的有效项仍须被清理")
    }

    @Test("嵌套父子路径重叠时先删父目录，子路径消失后跳过且不重复计入")
    func cleanupNestedParentChildDoesNotAbort() async throws {
        let root = try makeTempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let google = try makeDir(root, "Google", bytes: 128)
        let chrome = google.appendingPathComponent("Chrome", isDirectory: true)
        try FileManager.default.createDirectory(at: chrome, withIntermediateDirectories: true)
        try Data(repeating: 0x42, count: 64).write(to: chrome.appendingPathComponent("cache.bin"))

        // 父目录体积已含子目录字节（128 + 64）。
        let paths = [cachePath(google, size: 192), cachePath(chrome, size: 64)]

        let freed = try await CacheCleanerService.shared.cleanup(paths: paths, toleratingMissing: true)

        #expect(freed == 192, "子路径随父目录消失后不得再计入一次")
        #expect(!FileManager.default.fileExists(atPath: google.path))
    }

    @Test("按规范化路径去重：尾斜杠变体视为同一路径")
    func cleanupDeduplicatesByNormalizedPath() async throws {
        let root = try makeTempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let firefox = try makeDir(root, "Firefox", bytes: 128)

        // 两个路径字符串不同（一个带尾斜杠），规范化后指向同一目录。
        let trailingSlash = CachePath(
            path: firefox.path + "/", name: "Firefox", description: "", size: 128, fileCount: 1, canDelete: true
        )
        let paths = [cachePath(firefox, size: 128), trailingSlash]

        // 默认（严格）模式：仅靠规范化去重避免第二次删除抛错。
        let freed = try await CacheCleanerService.shared.cleanup(paths: paths)

        #expect(freed == 128, "规范化后同一路径只计一次")
        #expect(!FileManager.default.fileExists(atPath: firefox.path))
    }

    @Test("工具流程（默认）删除缺失路径仍抛错，保持 #740 契约")
    func cleanupStillThrowsOnMissingPathByDefault() async throws {
        let root = try makeTempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let missing = root.appendingPathComponent("DoesNotExist", isDirectory: true)

        await #expect(throws: CacheCleanupError.self) {
            _ = try await CacheCleanerService.shared.cleanup(paths: [cachePath(missing, size: 0)])
        }
    }
}
