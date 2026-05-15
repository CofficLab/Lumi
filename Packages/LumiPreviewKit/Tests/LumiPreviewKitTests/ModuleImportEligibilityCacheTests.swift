import Foundation
import LumiPreviewKit
import Testing
@testable import LumiPreviewKit

@Suite("ModuleImportEligibilityCache")
struct ModuleImportEligibilityCacheTests {
    @Test("reuses cache key for unchanged discovery inputs")
    func reusesCacheKeyForUnchangedDiscoveryInputs() async {
        let cache = LumiPreviewPackage.ModuleImportEligibilityCache()
        let discovery = makeDiscovery(bodySource: "DemoView()", sourceText: "struct DemoView: View {}")

        let first = await cache.makeCacheKey(discovery: discovery)
        let second = await cache.makeCacheKey(discovery: discovery)

        #expect(first == second)
    }

    @Test("changes to source text produce a different key")
    func changesToSourceTextProduceDifferentKey() async {
        let cache = LumiPreviewPackage.ModuleImportEligibilityCache()

        let first = await cache.makeCacheKey(
            discovery: makeDiscovery(
                bodySource: "DemoView()",
                sourceText: "struct DemoView: View {}"
            )
        )
        let second = await cache.makeCacheKey(
            discovery: makeDiscovery(
                bodySource: "DemoView()",
                sourceText: "private struct PrivateHelperView: View {}"
            )
        )

        #expect(first != second)
    }

    @Test("stores and returns eligibility values")
    func storesAndReturnsEligibilityValues() async {
        let cache = LumiPreviewPackage.ModuleImportEligibilityCache()
        let key = await cache.makeCacheKey(
            discovery: makeDiscovery(bodySource: "DemoView()", sourceText: "struct DemoView: View {}")
        )

        #expect(await cache.value(for: key) == nil)
        await cache.store(true, for: key)
        #expect(await cache.value(for: key) == true)
    }

    private func makeDiscovery(
        bodySource: String,
        sourceText: String
    ) -> LumiPreviewPackage.PreviewDiscovery {
        LumiPreviewPackage.PreviewDiscovery(
            id: "preview-id",
            title: "Preview",
            sourceFileURL: URL(fileURLWithPath: "/tmp/Preview.swift"),
            lineNumber: 8,
            endLineNumber: 12,
            primaryTypeName: "PreviewView",
            bodySource: bodySource,
            sourceText: sourceText
        )
    }
}
