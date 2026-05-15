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

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumiPreviewKitTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
