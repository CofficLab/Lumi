import Foundation
import LumiPreviewKit
import Testing
@testable import LumiPreviewKit

@Suite("CompileCommandCache")
struct CompileCommandCacheTests {
    @Test("stores and reloads commands by build strategy and file")
    func storesAndReloadsCommands() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appendingPathComponent("Preview.swift")
        try Data().write(to: fileURL)
        try Data("let package = Package(name: \"Demo\")".utf8)
            .write(to: directory.appendingPathComponent("Package.swift"))
        let buildStrategy = LumiPreviewFacade.BuildStrategy.spm(
            packageDirectory: directory,
            targetName: "Demo"
        )

        let cache = LumiPreviewFacade.CompileCommandCache(cacheDirectory: directory)
        let key = await cache.makeCacheKey(for: fileURL, buildStrategy: buildStrategy)
        await cache.store(command: "swift-frontend Demo", for: fileURL, key: key)

        let reloaded = LumiPreviewFacade.CompileCommandCache(cacheDirectory: directory)
        let reloadedKey = await reloaded.makeCacheKey(for: fileURL, buildStrategy: buildStrategy)

        #expect(await reloaded.command(for: reloadedKey) == "swift-frontend Demo")
        #expect(await reloaded.entryCount() == 1)
    }

    @Test("changes source metadata produce a different key")
    func sourceMetadataInvalidatesKey() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appendingPathComponent("Preview.swift")
        try Data("let value = 1".utf8).write(to: fileURL)
        try Data("let package = Package(name: \"Demo\")".utf8)
            .write(to: directory.appendingPathComponent("Package.swift"))
        let buildStrategy = LumiPreviewFacade.BuildStrategy.spm(
            packageDirectory: directory,
            targetName: "Demo"
        )

        let cache = LumiPreviewFacade.CompileCommandCache(cacheDirectory: directory)
        let firstKey = await cache.makeCacheKey(for: fileURL, buildStrategy: buildStrategy)
        try Data("let value = 1000".utf8).write(to: fileURL)
        let secondKey = await cache.makeCacheKey(for: fileURL, buildStrategy: buildStrategy)

        #expect(firstKey != secondKey)
    }

    @Test("changes package manifest metadata produce a different key")
    func packageManifestMetadataInvalidatesKey() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appendingPathComponent("Preview.swift")
        let packageURL = directory.appendingPathComponent("Package.swift")
        try Data("let value = 1".utf8).write(to: fileURL)
        try Data("let package = Package(name: \"Demo\")".utf8).write(to: packageURL)
        let buildStrategy = LumiPreviewFacade.BuildStrategy.spm(
            packageDirectory: directory,
            targetName: "Demo"
        )

        let cache = LumiPreviewFacade.CompileCommandCache(cacheDirectory: directory)
        let firstKey = await cache.makeCacheKey(for: fileURL, buildStrategy: buildStrategy)
        try Data("let package = Package(name: \"DemoChanged\")".utf8).write(to: packageURL)
        let secondKey = await cache.makeCacheKey(for: fileURL, buildStrategy: buildStrategy)

        #expect(firstKey != secondKey)
    }

    @Test("removes stored command for a cache key")
    func removesStoredCommand() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appendingPathComponent("Preview.swift")
        try Data().write(to: fileURL)
        try Data("let package = Package(name: \"Demo\")".utf8)
            .write(to: directory.appendingPathComponent("Package.swift"))
        let buildStrategy = LumiPreviewFacade.BuildStrategy.spm(
            packageDirectory: directory,
            targetName: "Demo"
        )

        let cache = LumiPreviewFacade.CompileCommandCache(cacheDirectory: directory)
        let key = await cache.makeCacheKey(for: fileURL, buildStrategy: buildStrategy)
        await cache.store(command: "swift-frontend Demo", for: fileURL, key: key)

        await cache.removeCommand(for: key)

        #expect(await cache.command(for: key) == nil)
        #expect(await cache.entryCount() == 0)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumiPreviewKitTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
