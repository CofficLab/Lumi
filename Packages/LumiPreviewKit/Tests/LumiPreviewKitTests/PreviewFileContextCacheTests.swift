import Foundation
import Testing
@testable import LumiPreviewKit

@Suite("PreviewFileContextCache")
struct PreviewFileContextCacheTests {
    @Test("file key 使用标准化符号链接解析路径")
    func fileKeyUsesStandardizedResolvedPath() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumiPreviewFileKey-\(UUID().uuidString)", isDirectory: true)
        let realDirectory = directory.appendingPathComponent("Real", isDirectory: true)
        let realFile = realDirectory.appendingPathComponent("Preview.swift")
        let symlink = directory.appendingPathComponent("Link.swift")
        try FileManager.default.createDirectory(at: realDirectory, withIntermediateDirectories: true)
        try "struct Preview {}\n".write(to: realFile, atomically: true, encoding: .utf8)
        try FileManager.default.createSymbolicLink(at: symlink, withDestinationURL: realFile)
        defer { try? FileManager.default.removeItem(at: directory) }

        let key = PreviewFileContextCache<String>.key(for: symlink)

        #expect(key == realFile.standardizedFileURL.resolvingSymlinksInPath().path)
    }

    @Test("store 和 remove 支持 URL 与 key")
    func storeAndRemoveByURLAndKey() {
        var cache = PreviewFileContextCache<String>(maximumCount: 2)
        let fileURL = URL(fileURLWithPath: "/tmp/Preview.swift")
        let key = PreviewFileContextCache<String>.key(for: fileURL)

        #expect(cache.store("first", for: fileURL).isEmpty)
        #expect(cache.value(forKey: key) == "first")
        #expect(cache.count == 1)

        #expect(cache.store("updated", forKey: key).isEmpty)
        #expect(cache.value(for: fileURL) == "updated")
        #expect(cache.count == 1)

        #expect(cache.removeValue(for: fileURL) == "updated")
        #expect(cache.value(forKey: key) == nil)
        #expect(cache.count == 0)
    }

    @Test("超过 maximumCount 时淘汰最久未使用的 context")
    func storeEvictsLeastRecentlyUsedContext() {
        var cache = PreviewFileContextCache<Int>(maximumCount: 2)

        #expect(cache.store(1, forKey: "a").isEmpty)
        #expect(cache.store(2, forKey: "b").isEmpty)
        let evicted = cache.store(3, forKey: "c")

        #expect(evicted.count == 1)
        #expect(evicted.first?.key == "a")
        #expect(evicted.first?.value == 1)
        #expect(cache.value(forKey: "a") == nil)
        #expect(cache.value(forKey: "b") == 2)
        #expect(cache.value(forKey: "c") == 3)
        #expect(cache.keysInLeastRecentOrder == ["b", "c"])
    }

    @Test("重新 store 已有 key 会刷新最近使用顺序")
    func storingExistingKeyRefreshesRecency() {
        var cache = PreviewFileContextCache<Int>(maximumCount: 2)

        cache.store(1, forKey: "a")
        cache.store(2, forKey: "b")
        cache.store(10, forKey: "a")
        let evicted = cache.store(3, forKey: "c")

        #expect(evicted.count == 1)
        #expect(evicted.first?.key == "b")
        #expect(cache.value(forKey: "a") == 10)
        #expect(cache.value(forKey: "b") == nil)
        #expect(cache.value(forKey: "c") == 3)
        #expect(cache.keysInLeastRecentOrder == ["a", "c"])
    }

    @Test("markRecentlyUsed 手动刷新 LRU 顺序")
    func markRecentlyUsedRefreshesRecency() {
        var cache = PreviewFileContextCache<Int>(maximumCount: 2)

        cache.store(1, forKey: "a")
        cache.store(2, forKey: "b")
        cache.markRecentlyUsed("a")
        let evicted = cache.store(3, forKey: "c")

        #expect(evicted.first?.key == "b")
        #expect(cache.keysInLeastRecentOrder == ["a", "c"])
    }

    @Test("maximumCount 为 0 时不缓存并返回被移除 context")
    func zeroMaximumCountDisablesCaching() {
        var cache = PreviewFileContextCache<Int>(maximumCount: 0)

        let firstEviction = cache.store(1, forKey: "a")
        #expect(firstEviction.isEmpty)
        #expect(cache.count == 0)

        var oneItemCache = PreviewFileContextCache<Int>(maximumCount: 1)
        oneItemCache.store(1, forKey: "a")
        let removed = oneItemCache.removeValue(forKey: "a")
        #expect(removed == 1)
    }
}
