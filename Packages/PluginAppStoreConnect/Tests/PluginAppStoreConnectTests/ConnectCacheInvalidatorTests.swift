import Foundation
import KitTestSupport
import Testing
@testable import PluginAppStoreConnect

/// 写操作成功后必须失效对应的读取缓存,否则紧接的读取会拿到旧值。
///
/// 覆盖四条链路：年龄分级声明、版本属性、截图变更、审核提交。
@Suite("ConnectCacheInvalidator")
struct ConnectCacheInvalidatorTests {

    private static let accountKey = "issuer|key"

    // MARK: - Helpers

    /// 建一个落在临时目录的缓存。
    private func makeCache() throws -> (ConnectAPICache, TemporaryDirectory) {
        let directory = try TemporaryDirectory.make("asc-cache-invalidator")
        let cache = ConnectAPICache(rootDirectory: directory.url)
        return (cache, directory)
    }

    /// 往缓存里塞一条 GET 条目,返回其逻辑 key。
    @discardableResult
    private func seed(
        _ cache: ConnectAPICache,
        path: String,
        tags: [ConnectCacheTag] = [],
        accountKey: String = ConnectCacheInvalidatorTests.accountKey
    ) -> String {
        let key = "\(accountKey)|GET|\(path)|"
        cache.set(
            logicalKey: key,
            method: "GET",
            path: path,
            data: Data("{}".utf8),
            now: Date()
        )
        return key
    }

    private func isCached(_ cache: ConnectAPICache, path: String) -> Bool {
        let key = "\(ConnectCacheInvalidatorTests.accountKey)|GET|\(path)|"
        return cache.get(logicalKey: key, fetchPolicy: .cacheFirst) != nil
    }

    private func invalidate(
        _ cache: ConnectAPICache,
        method: String,
        path: String,
        body: Data? = nil
    ) {
        cache.invalidateAfterMutation(
            method: method,
            path: path,
            body: body,
            accountKey: ConnectCacheInvalidatorTests.accountKey
        )
    }

    // MARK: - 年龄分级声明 (#716)

    @Test("年龄分级 PATCH 后失效 appInfo 声明读取缓存")
    func ageRatingPatchInvalidatesDeclarationRead() throws {
        let (cache, directory) = try makeCache()
        defer { directory.remove() }

        let path = "/v1/appInfos/app-info-1/ageRatingDeclaration"
        seed(cache, path: path)
        #expect(isCached(cache, path: path))

        invalidate(cache, method: "PATCH", path: "/v1/ageRatingDeclarations/decl-1")

        #expect(!isCached(cache, path: path))
    }

    @Test("年龄分级 PATCH 不影响无关的缓存条目")
    func ageRatingPatchKeepsUnrelatedEntries() throws {
        let (cache, directory) = try makeCache()
        defer { directory.remove() }

        let unrelated = "/v1/apps"
        seed(cache, path: unrelated)

        invalidate(cache, method: "PATCH", path: "/v1/ageRatingDeclarations/decl-1")

        #expect(isCached(cache, path: unrelated))
    }

    // MARK: - 版本属性 (#714)

    @Test("版本 PATCH 后失效版本详情与版本列表缓存")
    func versionPatchInvalidatesDetailAndList() throws {
        let (cache, directory) = try makeCache()
        defer { directory.remove() }

        let detail = "/v1/appStoreVersions/version-1"
        let list = "/v1/apps/app-1/appStoreVersions"
        seed(cache, path: detail)
        seed(cache, path: list)
        #expect(isCached(cache, path: detail))
        #expect(isCached(cache, path: list))

        invalidate(cache, method: "PATCH", path: "/v1/appStoreVersions/version-1")

        #expect(!isCached(cache, path: detail))
        #expect(!isCached(cache, path: list))
    }

    @Test("版本 PATCH 不影响其它版本的详情")
    func versionPatchKeepsOtherVersions() throws {
        let (cache, directory) = try makeCache()
        defer { directory.remove() }

        let other = "/v1/appStoreVersions/version-2"
        seed(cache, path: other)

        invalidate(cache, method: "PATCH", path: "/v1/appStoreVersions/version-1")

        #expect(isCached(cache, path: other))
    }

    // MARK: - 关联 build (#668)

    @Test("关联 build 后失效该版本的关系读取缓存")
    func buildAssignmentPatchInvalidatesRelationshipRead() throws {
        let (cache, directory) = try makeCache()
        defer { directory.remove() }

        // 关联前的读取缓存是 {"data": null}，若生命周期结束后仍被复用，
        // 提交前置检查会误判「没有 build」。
        let path = "/v1/appStoreVersions/version-1/relationships/build"
        seed(cache, path: path)
        #expect(isCached(cache, path: path))

        let body = try JSONSerialization.data(withJSONObject: [
            "data": ["type": "builds", "id": "build-1"]
        ])
        invalidate(cache, method: "PATCH", path: path, body: body)

        #expect(!isCached(cache, path: path))
    }

    @Test("关联 build 不影响其它版本的关系读取缓存")
    func buildAssignmentPatchKeepsOtherVersions() throws {
        let (cache, directory) = try makeCache()
        defer { directory.remove() }

        let other = "/v1/appStoreVersions/version-2/relationships/build"
        seed(cache, path: other)

        invalidate(cache, method: "PATCH", path: "/v1/appStoreVersions/version-1/relationships/build")

        #expect(isCached(cache, path: other))
    }

    // MARK: - 截图变更 (#715)

    @Test("截图预约上传后失效截图列表缓存")
    func screenshotReserveInvalidatesLists() throws {
        let (cache, directory) = try makeCache()
        defer { directory.remove() }

        let relationshipList = "/v1/appScreenshotSets/set-1/appScreenshots"
        let filteredList = "/v1/appScreenshots"
        seed(cache, path: relationshipList)
        seed(cache, path: filteredList)

        let body = try JSONSerialization.data(withJSONObject: [
            "data": [
                "type": "appScreenshots",
                "relationships": [
                    "appScreenshotSet": ["data": ["type": "appScreenshotSets", "id": "set-1"]]
                ]
            ]
        ])
        invalidate(cache, method: "POST", path: "/v1/appScreenshots", body: body)

        #expect(!isCached(cache, path: relationshipList))
        #expect(!isCached(cache, path: filteredList))
    }

    @Test("截图上传完成后失效截图列表缓存")
    func screenshotCompletionInvalidatesLists() throws {
        let (cache, directory) = try makeCache()
        defer { directory.remove() }

        let path = "/v1/appScreenshots"
        seed(cache, path: path)

        invalidate(cache, method: "PATCH", path: "/v1/appScreenshots/shot-1")

        #expect(!isCached(cache, path: path))
    }

    @Test("截图删除后失效截图列表缓存")
    func screenshotDeleteInvalidatesLists() throws {
        let (cache, directory) = try makeCache()
        defer { directory.remove() }

        let path = "/v1/appScreenshots"
        seed(cache, path: path)

        invalidate(cache, method: "DELETE", path: "/v1/appScreenshots/shot-1")

        #expect(!isCached(cache, path: path))
    }

    // MARK: - 审核提交 (#713)

    @Test("创建审核提交后失效提交列表缓存")
    func submissionCreateInvalidatesList() throws {
        let (cache, directory) = try makeCache()
        defer { directory.remove() }

        let path = "/v1/apps/app-1/reviewSubmissions"
        seed(cache, path: path)

        invalidate(cache, method: "POST", path: "/v1/reviewSubmissions")

        #expect(!isCached(cache, path: path))
    }

    @Test("触发提交后失效提交项缓存")
    func submissionTriggerInvalidatesItems() throws {
        let (cache, directory) = try makeCache()
        defer { directory.remove() }

        let path = "/v1/reviewSubmissions/sub-1/items"
        seed(cache, path: path)

        invalidate(cache, method: "PATCH", path: "/v1/reviewSubmissions/sub-1")

        #expect(!isCached(cache, path: path))
    }

    @Test("撤回提交后失效提交列表缓存")
    func submissionWithdrawInvalidatesList() throws {
        let (cache, directory) = try makeCache()
        defer { directory.remove() }

        let path = "/v1/apps/app-1/reviewSubmissions"
        seed(cache, path: path)

        invalidate(cache, method: "PATCH", path: "/v1/reviewSubmissions/sub-1")

        #expect(!isCached(cache, path: path))
    }

    // MARK: - 内存缓存失效（根因回归）

    @Test("accountKey 含分隔符时内存缓存同样被失效")
    func memoryCacheIsInvalidatedWhenAccountKeyContainsSeparator() throws {
        let (cache, directory) = try makeCache()
        defer { directory.remove() }

        // accountKey 形如 `issuerID|keyID`，本身含 `|`，
        // 解析内存缓存 key 时若不先剥掉前缀就会错位，导致内存条目残留。
        let path = "/v1/apps/app-1/reviewSubmissions"
        seed(cache, path: path)
        #expect(isCached(cache, path: path))

        invalidate(cache, method: "POST", path: "/v1/reviewSubmissions")

        #expect(!isCached(cache, path: path))
    }

    @Test("内存缓存失效不影响其它账户的条目")
    func memoryInvalidationIsScopedToAccount() throws {
        let (cache, directory) = try makeCache()
        defer { directory.remove() }

        let otherPath = "/v1/apps/app-1/reviewSubmissions"
        let otherAccount = "other-issuer|other-key"
        let otherKey = "\(otherAccount)|GET|\(otherPath)|"
        cache.set(logicalKey: otherKey, method: "GET", path: otherPath, data: Data("{}".utf8), now: Date())

        invalidate(cache, method: "POST", path: "/v1/reviewSubmissions")

        #expect(cache.get(logicalKey: otherKey, fetchPolicy: .cacheFirst) != nil)
    }
}
