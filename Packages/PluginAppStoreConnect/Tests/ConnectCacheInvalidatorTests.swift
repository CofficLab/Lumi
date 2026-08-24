import Testing
import Foundation
@testable import AppStoreConnectPlugin

/// Regression tests for `ConnectCacheInvalidator`, focusing on the operator-
/// precedence fix in the PATCH localization branch.
@Suite struct ConnectCacheInvalidatorTests {

    /// Build a fresh isolated cache rooted in a temp directory.
    private func makeCache() -> ConnectAPICache {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("asc-cache-\(UUID().uuidString)", isDirectory: true)
        return ConnectAPICache(rootDirectory: root)
    }

    @Test func patchLocalizationInvalidatesOnlyMatchingEntries() throws {
        let cache = makeCache()
        let accountKey = "acct"

        // Entry A: screenshot set for a DIFFERENT localization ("loc-other").
        // Before the fix this was wrongly invalidated because `B && C` precedence
        // made any /appScreenshotSets path invalidate regardless of localizationID.
        _ = cache.diskStore.store(
            logicalKey: "\(accountKey)|screenshots-other",
            method: "GET", path: "/v1/appScreenshotSets?filter[appStoreVersionLocalization]=loc-other",
            retention: .standard, tags: [.localization("loc-other")],
            data: Data("{}".utf8)
        )
        // Entry B: screenshot set for the SAME localization ("loc-1").
        _ = cache.diskStore.store(
            logicalKey: "\(accountKey)|screenshots-1",
            method: "GET", path: "/v1/appScreenshotSets?filter[appStoreVersionLocalization]=loc-1",
            retention: .standard, tags: [.localization("loc-1")],
            data: Data("{}".utf8)
        )

        cache.invalidateAfterMutation(
            method: "PATCH",
            path: "/v1/appStoreVersionLocalizations/loc-1",
            body: nil,
            accountKey: accountKey
        )

        // The same-localization entry must be gone…
        #expect(cache.diskStore.read(logicalKey: "\(accountKey)|screenshots-1", now: Date()) == nil)
        // …but the unrelated localization entry must survive.
        #expect(cache.diskStore.read(logicalKey: "\(accountKey)|screenshots-other", now: Date()) != nil)
    }

    @Test func patchCiWorkflowInvalidatesCiEntries() throws {
        let cache = makeCache()
        let accountKey = "acct"
        _ = cache.diskStore.store(
            logicalKey: "\(accountKey)|ci-flows", method: "GET",
            path: "/v1/ciWorkflows", retention: .standard, tags: [],
            data: Data("{}".utf8)
        )

        cache.invalidateAfterMutation(
            method: "PATCH", path: "/v1/ciWorkflows/wf-1",
            body: nil, accountKey: accountKey
        )
        #expect(cache.diskStore.read(logicalKey: "\(accountKey)|ci-flows", now: Date()) == nil)
    }
}
