import AppKit
import Foundation
import Testing
@testable import PluginDiskManager

/// 回归 #1223：Directory Tree / Large Files / Cache Cleaner 的行视图过去在
/// SwiftUI `body` 的计算属性里直接调用 `NSWorkspace.shared.icon(forFile:)`，
/// 每次 body 重新求值（选中、删除确认、进度刷新）都重复同一次同步 workspace 查询。
/// `WorkspaceIconCache` 让每条路径在图标生命周期内至多查询一次，并跨求值复用。
@MainActor
@Suite struct WorkspaceIconCacheTests {

    /// 记录每条路径的查询次数；每次查询返回全新 `NSImage`，
    /// 以便用实例同一性区分「命中缓存」与「再次查询」。
    private final class LookupRecorder {
        var counts: [String: Int] = [:]
        func lookup(_ path: String) -> NSImage {
            counts[path, default: 0] += 1
            return NSImage()
        }
    }

    @Test func iconQueriesOncePerPathAndReusesInstance() {
        let recorder = LookupRecorder()
        let cache = WorkspaceIconCache(limit: 16, lookup: recorder.lookup)

        let first = cache.icon(forPath: "/a")
        let second = cache.icon(forPath: "/a")

        #expect(recorder.counts["/a"] == 1)
        #expect(first === second)
    }

    @Test func distinctPathsAreQueriedSeparately() {
        let recorder = LookupRecorder()
        let cache = WorkspaceIconCache(limit: 16, lookup: recorder.lookup)

        _ = cache.icon(forPath: "/a")
        _ = cache.icon(forPath: "/b")
        _ = cache.icon(forPath: "/a")
        _ = cache.icon(forPath: "/b")

        #expect(recorder.counts["/a"] == 1)
        #expect(recorder.counts["/b"] == 1)
    }

    @Test func cacheEvictsOldestBeyondLimit() {
        let recorder = LookupRecorder()
        let cache = WorkspaceIconCache(limit: 2, lookup: recorder.lookup)

        _ = cache.icon(forPath: "/a")
        _ = cache.icon(forPath: "/b")
        _ = cache.icon(forPath: "/c")   // 超出上限，淘汰最旧的 /a
        #expect(recorder.counts["/a"] == 1)

        _ = cache.icon(forPath: "/a")   // /a 已被淘汰，需再次查询
        #expect(recorder.counts["/a"] == 2)
        #expect(recorder.counts["/c"] == 1)
    }

    @Test func prefetchPopulatesCacheWithoutExtraQueries() {
        let recorder = LookupRecorder()
        let cache = WorkspaceIconCache(limit: 16, lookup: recorder.lookup)

        cache.prefetch(paths: ["/a", "/b"])
        _ = cache.icon(forPath: "/a")
        _ = cache.icon(forPath: "/b")

        #expect(recorder.counts["/a"] == 1)
        #expect(recorder.counts["/b"] == 1)
    }

    @Test func removeAllForcesRequery() {
        let recorder = LookupRecorder()
        let cache = WorkspaceIconCache(limit: 16, lookup: recorder.lookup)

        _ = cache.icon(forPath: "/a")
        cache.removeAll()
        _ = cache.icon(forPath: "/a")

        #expect(recorder.counts["/a"] == 2)
    }
}