import Foundation
import LumiPreviewKit
import Testing
@testable import LumiHotPreviewKit

@Suite("EntryCacheManager")
struct EntryCacheManagerTests {
    @Test("reuses the same key for unchanged preview inputs")
    func reusesSameKeyForUnchangedInputs() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = LumiHotPreviewPackage.EntryCacheManager(
            cacheRootDirectory: directory,
            maximumEntryCount: 4
        )
        let discovery = makeDiscovery(bodySource: "Text(\"Hello\")")

        let first = await manager.makeCacheKey(
            discovery: discovery,
            configuration: .empty,
            buildStrategy: .spm(packageDirectory: discovery.sourceFileURL.deletingLastPathComponent(), targetName: "Demo")
        )
        let second = await manager.makeCacheKey(
            discovery: discovery,
            configuration: .empty,
            buildStrategy: .spm(packageDirectory: discovery.sourceFileURL.deletingLastPathComponent(), targetName: "Demo")
        )

        #expect(first == second)
    }

    @Test("uses different cache keys for different entry variants")
    func usesDifferentCacheKeysForDifferentEntryVariants() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = LumiHotPreviewPackage.EntryCacheManager(
            cacheRootDirectory: directory,
            maximumEntryCount: 4
        )
        let discovery = makeDiscovery(bodySource: "Text(\"Hello\")")
        let strategy = LumiPreviewPackage.BuildStrategy.xcode(
            projectURL: URL(fileURLWithPath: "/tmp/Demo.xcodeproj"),
            scheme: "Demo",
            configuration: "Debug"
        )

        let moduleImportKey = await manager.makeCacheKey(
            discovery: discovery,
            configuration: .empty,
            buildStrategy: strategy,
            entryVariant: "module-import"
        )
        let sourceIncludeKey = await manager.makeCacheKey(
            discovery: discovery,
            configuration: .empty,
            buildStrategy: strategy,
            entryVariant: "source-include"
        )

        #expect(moduleImportKey != sourceIncludeKey)
    }

    @Test("returns a stored entry when the dylib still exists")
    func returnsStoredEntryWhenDylibExists() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = LumiHotPreviewPackage.EntryCacheManager(
            cacheRootDirectory: directory,
            maximumEntryCount: 4
        )
        let discovery = makeDiscovery(bodySource: "Text(\"Hello\")")
        let key = await manager.makeCacheKey(discovery: discovery, configuration: .empty, buildStrategy: nil)
        let dylibURL = directory.appendingPathComponent("PreviewEntry.dylib")
        try Data("fake".utf8).write(to: dylibURL)

        await manager.storeEntryURL(dylibURL, for: key)

        let cached = await manager.cachedEntryURL(for: key)
        #expect(cached == dylibURL)
        #expect(await manager.cachedEntryCount() == 1)
    }

    @Test("evicts least recently used entries beyond the limit")
    func evictsLeastRecentlyUsedEntries() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = LumiHotPreviewPackage.EntryCacheManager(
            cacheRootDirectory: directory,
            maximumEntryCount: 2
        )

        let firstDiscovery = makeDiscovery(id: "first", bodySource: "Text(\"First\")")
        let secondDiscovery = makeDiscovery(id: "second", bodySource: "Text(\"Second\")")
        let thirdDiscovery = makeDiscovery(id: "third", bodySource: "Text(\"Third\")")

        let firstKey = await manager.makeCacheKey(discovery: firstDiscovery, configuration: .empty, buildStrategy: nil)
        let secondKey = await manager.makeCacheKey(discovery: secondDiscovery, configuration: .empty, buildStrategy: nil)
        let thirdKey = await manager.makeCacheKey(discovery: thirdDiscovery, configuration: .empty, buildStrategy: nil)

        let firstURL = directory.appendingPathComponent("first.dylib")
        let secondURL = directory.appendingPathComponent("second.dylib")
        let thirdURL = directory.appendingPathComponent("third.dylib")
        try Data("first".utf8).write(to: firstURL)
        try Data("second".utf8).write(to: secondURL)
        try Data("third".utf8).write(to: thirdURL)

        await manager.storeEntryURL(firstURL, for: firstKey)
        try await Task.sleep(nanoseconds: 1_000_000)
        await manager.storeEntryURL(secondURL, for: secondKey)
        _ = await manager.cachedEntryURL(for: firstKey)
        try await Task.sleep(nanoseconds: 1_000_000)
        await manager.storeEntryURL(thirdURL, for: thirdKey)

        #expect(await manager.cachedEntryURL(for: firstKey) == firstURL)
        #expect(await manager.cachedEntryURL(for: secondKey) == nil)
        #expect(await manager.cachedEntryURL(for: thirdKey) == thirdURL)
        #expect(await manager.cachedEntryCount() == 2)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumiHotPreviewKitTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func makeDiscovery(
        id: String = "preview-id",
        bodySource: String
    ) -> LumiPreviewPackage.PreviewDiscovery {
        LumiPreviewPackage.PreviewDiscovery(
            id: id,
            title: "Preview",
            sourceFileURL: URL(fileURLWithPath: "/tmp/Preview.swift"),
            lineNumber: 10,
            endLineNumber: 20,
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
