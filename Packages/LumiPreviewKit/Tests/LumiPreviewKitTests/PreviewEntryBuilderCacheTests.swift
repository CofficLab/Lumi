import Foundation
import LumiPreviewKit
import Testing
@testable import LumiPreviewKit

@Suite("PreviewEntryBuilderCache")
struct PreviewEntryBuilderCacheTests {
    @Test("3.4 removeExpiredCacheEntries deletes stale directories")
    func removeExpiredCacheEntriesDeletesStaleDirectories() throws {
        let root = try TemporaryProjectFixtures.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let staleDirectory = root.appendingPathComponent("stale", isDirectory: true)
        let freshDirectory = root.appendingPathComponent("fresh", isDirectory: true)
        try FileManager.default.createDirectory(at: staleDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: freshDirectory, withIntermediateDirectories: true)
        try Data().write(to: staleDirectory.appendingPathComponent("PreviewEntry.dylib"))
        try Data().write(to: freshDirectory.appendingPathComponent("PreviewEntry.dylib"))

        let staleDate = Date(timeIntervalSinceNow: -8 * 24 * 60 * 60)
        try FileManager.default.setAttributes([.modificationDate: staleDate], ofItemAtPath: staleDirectory.path)

        LumiPreviewFacade.PreviewEntryBuilder.removeExpiredCacheEntries(
            olderThan: 7 * 24 * 60 * 60,
            keepingNewest: 8,
            fileManager: .default,
            rootDirectory: root,
            now: Date()
        )

        #expect(FileManager.default.fileExists(atPath: staleDirectory.path) == false)
        #expect(FileManager.default.fileExists(atPath: freshDirectory.path))
    }

    @Test("3.5 buildEntry reuses cached dylib for unchanged inputs")
    func buildEntryReusesCachedDylib() async throws {
        let directory = try TemporaryProjectFixtures.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appendingPathComponent("CachedEntry.swift")
        try TemporaryProjectFixtures.writeSwiftFileWithPreview(at: fileURL, previewLabel: "CachedEntry")

        let discovery = PreviewDiscoveryFixtures.makeDiscovery(
            fileURL: fileURL,
            bodySource: "Text(\"Cached\")"
        )
        let builder = LumiPreviewFacade.PreviewEntryBuilder()
        let firstURL = try await builder.buildEntry(for: discovery, configuration: .empty, buildStrategy: nil)
        let secondURL = try await builder.buildEntry(for: discovery, configuration: .empty, buildStrategy: nil)

        #expect(firstURL == secondURL)
        #expect(FileManager.default.fileExists(atPath: firstURL.path))
    }

    @Test("3.6 buildEntry rebuilds when cached dylib is deleted")
    func buildEntryRebuildsAfterCacheDeletion() async throws {
        let directory = try TemporaryProjectFixtures.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appendingPathComponent("RebuildEntry.swift")
        try TemporaryProjectFixtures.writeSwiftFileWithPreview(at: fileURL, previewLabel: "RebuildEntry")

        let discovery = PreviewDiscoveryFixtures.makeDiscovery(
            fileURL: fileURL,
            bodySource: "Text(\"Rebuild\")"
        )
        let builder = LumiPreviewFacade.PreviewEntryBuilder()
        let firstURL = try await builder.buildEntry(for: discovery, configuration: .empty, buildStrategy: nil)
        try FileManager.default.removeItem(at: firstURL)

        let secondURL = try await builder.buildEntry(for: discovery, configuration: .empty, buildStrategy: nil)
        #expect(secondURL == firstURL)
        #expect(FileManager.default.fileExists(atPath: secondURL.path))
    }
}
