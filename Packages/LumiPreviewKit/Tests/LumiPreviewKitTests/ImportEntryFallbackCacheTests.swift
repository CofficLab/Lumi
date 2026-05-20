import Foundation
import LumiPreviewKit
import Testing
@testable import LumiPreviewKit

@Suite("ImportEntryFallbackCache")
struct ImportEntryFallbackCacheTests {
    @Test("records failures per preview fingerprint")
    func recordsFailuresPerPreviewFingerprint() async {
        let cache = LumiPreviewFacade.ImportEntryFallbackCache()
        let discovery = makeDiscovery(bodySource: "DemoView()")
        let strategy = LumiPreviewFacade.BuildStrategy.xcode(
            projectURL: URL(fileURLWithPath: "/tmp/Demo.xcodeproj"),
            scheme: "Demo",
            configuration: "Debug"
        )

        let key = await cache.makeCacheKey(
            discovery: discovery,
            configuration: .empty,
            buildStrategy: strategy
        )

        #expect(await cache.contains(key) == false)
        await cache.recordFailure(for: key)
        #expect(await cache.contains(key) == true)
        await cache.remove(key)
        #expect(await cache.contains(key) == false)
    }

    @Test("changes to preview body produce a different key")
    func changesToPreviewBodyProduceDifferentKey() async {
        let cache = LumiPreviewFacade.ImportEntryFallbackCache()
        let strategy = LumiPreviewFacade.BuildStrategy.spm(
            packageDirectory: URL(fileURLWithPath: "/tmp/Demo"),
            targetName: "DemoModule"
        )

        let firstKey = await cache.makeCacheKey(
            discovery: makeDiscovery(bodySource: "DemoView()"),
            configuration: .empty,
            buildStrategy: strategy
        )
        let secondKey = await cache.makeCacheKey(
            discovery: makeDiscovery(bodySource: "UpdatedDemoView()"),
            configuration: .empty,
            buildStrategy: strategy
        )

        #expect(firstKey != secondKey)
    }

    @Test("3.7 repeated failures keep a single fallback record")
    func repeatedFailuresKeepSingleRecord() async {
        let cache = LumiPreviewFacade.ImportEntryFallbackCache()
        let discovery = makeDiscovery(bodySource: "DemoView()")
        let strategy = LumiPreviewFacade.BuildStrategy.spm(
            packageDirectory: URL(fileURLWithPath: "/tmp/Demo"),
            targetName: "DemoModule"
        )
        let key = await cache.makeCacheKey(
            discovery: discovery,
            configuration: .empty,
            buildStrategy: strategy
        )

        await cache.recordFailure(for: key)
        await cache.recordFailure(for: key)

        #expect(await cache.contains(key))
    }

    @Test("3.8 configuration changes produce a different fallback key")
    func configurationChangesProduceDifferentFallbackKey() async {
        let cache = LumiPreviewFacade.ImportEntryFallbackCache()
        let discovery = makeDiscovery(bodySource: "DemoView()")
        let strategy = LumiPreviewFacade.BuildStrategy.spm(
            packageDirectory: URL(fileURLWithPath: "/tmp/Demo"),
            targetName: "DemoModule"
        )

        let firstKey = await cache.makeCacheKey(
            discovery: discovery,
            configuration: .empty,
            buildStrategy: strategy
        )
        let configured = LumiPreviewFacade.PreviewRenderConfiguration(
            environmentInjections: [
                LumiPreviewFacade.PreviewEnvironmentInjection(
                    typeName: "ColorScheme",
                    mockIdentifier: "dark"
                ),
            ]
        )
        let secondKey = await cache.makeCacheKey(
            discovery: discovery,
            configuration: configured,
            buildStrategy: strategy
        )

        #expect(firstKey != secondKey)
        await cache.recordFailure(for: firstKey)
        #expect(await cache.contains(firstKey))
        #expect(await cache.contains(secondKey) == false)
    }

    @Test("changes to module artifact fingerprint produce a different key")
    func changesToModuleArtifactFingerprintProduceDifferentKey() async {
        let cache = LumiPreviewFacade.ImportEntryFallbackCache()
        let strategy = LumiPreviewFacade.BuildStrategy.xcode(
            projectURL: URL(fileURLWithPath: "/tmp/Demo.xcodeproj"),
            scheme: "Demo",
            configuration: "Debug"
        )
        let discovery = makeDiscovery(bodySource: "DemoView()")

        let firstKey = await cache.makeCacheKey(
            discovery: discovery,
            configuration: .empty,
            buildStrategy: strategy,
            moduleArtifactFingerprint: "/tmp/Modules/Demo.swiftmodule|100|10"
        )
        let secondKey = await cache.makeCacheKey(
            discovery: discovery,
            configuration: .empty,
            buildStrategy: strategy,
            moduleArtifactFingerprint: "/tmp/Modules/Demo.swiftmodule|200|10"
        )

        #expect(firstKey != secondKey)
    }

    private func makeDiscovery(bodySource: String) -> LumiPreviewFacade.PreviewDiscovery {
        LumiPreviewFacade.PreviewDiscovery(
            id: "preview-id",
            title: "Preview",
            sourceFileURL: URL(fileURLWithPath: "/tmp/Preview.swift"),
            lineNumber: 12,
            endLineNumber: 16,
            primaryTypeName: "PreviewView",
            bodySource: bodySource,
            sourceText: """
            #Preview {
                \(bodySource)
            }
            """
        )
    }
}
