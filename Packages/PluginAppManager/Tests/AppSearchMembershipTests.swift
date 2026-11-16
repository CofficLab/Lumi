import Foundation
import Testing
@testable import AppManagerPlugin

/// Regression coverage for #1220: a refresh calculates each app's size in the
/// background and republishes `installedApps` per completion. The localized
/// name/bundle-ID search must only rerun when the query or searchable fields
/// change, not on every size-only update (which previously caused O(N²)
/// main-actor filtering).
@MainActor
struct AppSearchMembershipTests {

    @Test func sizeOnlyUpdatesDoNotRerunLocalizedSearch() {
        let membership = AppSearchMembership()
        var apps = [
            makeApp("Alpha", id: "com.test.alpha"),
            makeApp("Beta", id: "com.test.beta"),
            makeApp("Gamma", id: "com.test.gamma"),
        ]

        let first = membership.filtered(query: "alpha", apps: apps)
        #expect(first.map { $0.displayName } == ["Alpha"])
        #expect(membership.recomputeCount == 1)

        // Simulate the per-app size completions of one refresh: each republish
        // changes only `size`, so the cached membership must be reused.
        for i in 1...20 {
            apps[0].size = Int64(i) * 100
            apps[1].size = Int64(i) * 10
            apps[2].size = Int64(i)
            let result = membership.filtered(query: "alpha", apps: apps)
            #expect(result.map { $0.displayName } == ["Alpha"])
            #expect(result.first?.size == Int64(i) * 100)
        }
        #expect(membership.recomputeCount == 1)
    }

    @Test func queryChangeRerunsLocalizedSearch() {
        let membership = AppSearchMembership()
        let apps = [makeApp("Alpha", id: "com.test.alpha"), makeApp("Beta", id: "com.test.beta")]

        #expect(membership.filtered(query: "alpha", apps: apps).map { $0.displayName } == ["Alpha"])
        #expect(membership.recomputeCount == 1)
        #expect(membership.filtered(query: "beta", apps: apps).map { $0.displayName } == ["Beta"])
        #expect(membership.recomputeCount == 2)
    }

    @Test func membershipChangeRerunsLocalizedSearch() {
        let membership = AppSearchMembership()
        let apps = [makeApp("Alpha", id: "com.test.alpha"), makeApp("Beta", id: "com.test.beta")]
        #expect(membership.filtered(query: "alpha", apps: apps).count == 1)
        #expect(membership.recomputeCount == 1)

        let grown = apps + [makeApp("Alphabet", id: "com.test.alphabet")]
        let result = membership.filtered(query: "alpha", apps: grown)
        #expect(result.map { $0.displayName } == ["Alpha", "Alphabet"])
        #expect(membership.recomputeCount == 2)
    }

    @Test func emptyQueryReturnsAllAppsAndReflectsSizes() {
        let membership = AppSearchMembership()
        var apps = [makeApp("Alpha", id: "com.test.alpha"), makeApp("Beta", id: "com.test.beta")]

        #expect(membership.filtered(query: "", apps: apps).count == 2)
        #expect(membership.recomputeCount == 1)

        apps[0].size = 4096
        let result = membership.filtered(query: "", apps: apps)
        #expect(result.count == 2)
        #expect(result.first?.size == 4096)
        #expect(membership.recomputeCount == 1)
    }

    @Test func searchMatchesNameAndBundleIDCaseInsensitively() {
        let membership = AppSearchMembership()
        let apps = [makeApp("Alpha", id: "com.test.alpha"), makeApp("Beta", id: "com.test.beta")]

        #expect(membership.filtered(query: "ALPHA", apps: apps).map { $0.displayName } == ["Alpha"])
        #expect(membership.filtered(query: "COM.TEST.BETA", apps: apps).map { $0.displayName } == ["Beta"])
        #expect(membership.filtered(query: "zzz", apps: apps).isEmpty)
    }

    private func makeApp(_ name: String, id: String, size: Int64 = 0) -> AppModel {
        AppModel(
            bundleURL: URL(fileURLWithPath: "/Applications/\(name).app"),
            name: name,
            identifier: id,
            version: "1.0",
            iconFileName: nil,
            size: size
        )
    }
}