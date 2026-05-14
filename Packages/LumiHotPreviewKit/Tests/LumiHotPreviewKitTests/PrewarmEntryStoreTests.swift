import Foundation
import LumiPreviewKit
import Testing
@testable import LumiHotPreviewKit

@Suite("PrewarmEntryStore")
struct PrewarmEntryStoreTests {
    @Test("reuses stored entry when source fingerprint is unchanged")
    func reusesStoredEntryWhenSourceFingerprintIsUnchanged() async throws {
        let store = LumiHotPreviewPackage.HotPreviewEngine.PrewarmEntryStore()
        let directory = try makeTemporaryDirectory()
        let sourceURL = directory.appendingPathComponent("Preview.swift")
        let entryURL = directory.appendingPathComponent("PreviewEntry.dylib")
        try "struct Preview {}".write(to: sourceURL, atomically: true, encoding: .utf8)
        try Data([1, 2, 3]).write(to: entryURL)
        let discovery = makeDiscovery(sourceFileURL: sourceURL)

        await store.store(
            entryURL: entryURL,
            buildStrategy: nil,
            entryVariant: .sourceInclude,
            discovery: discovery,
            configuration: .empty
        )

        let entry = await store.entry(
            discovery: discovery,
            configuration: .empty,
            buildStrategy: nil
        )

        #expect(entry?.url == entryURL)
        #expect(entry?.variant == .sourceInclude)
    }

    @Test("invalidates stored entry when source file changes")
    func invalidatesStoredEntryWhenSourceFileChanges() async throws {
        let store = LumiHotPreviewPackage.HotPreviewEngine.PrewarmEntryStore()
        let directory = try makeTemporaryDirectory()
        let sourceURL = directory.appendingPathComponent("Preview.swift")
        let entryURL = directory.appendingPathComponent("PreviewEntry.dylib")
        try "struct Preview {}".write(to: sourceURL, atomically: true, encoding: .utf8)
        try Data([1, 2, 3]).write(to: entryURL)
        let discovery = makeDiscovery(sourceFileURL: sourceURL)

        await store.store(
            entryURL: entryURL,
            buildStrategy: nil,
            entryVariant: .sourceInclude,
            discovery: discovery,
            configuration: .empty
        )
        try "struct Preview { let value = 1 }".write(to: sourceURL, atomically: true, encoding: .utf8)

        let entry = await store.entry(
            discovery: discovery,
            configuration: .empty,
            buildStrategy: nil
        )

        #expect(entry == nil)
    }

    @Test("invalidates stored entry when entry file is missing")
    func invalidatesStoredEntryWhenEntryFileIsMissing() async throws {
        let store = LumiHotPreviewPackage.HotPreviewEngine.PrewarmEntryStore()
        let directory = try makeTemporaryDirectory()
        let sourceURL = directory.appendingPathComponent("Preview.swift")
        let entryURL = directory.appendingPathComponent("PreviewEntry.dylib")
        try "struct Preview {}".write(to: sourceURL, atomically: true, encoding: .utf8)
        try Data([1, 2, 3]).write(to: entryURL)
        let discovery = makeDiscovery(sourceFileURL: sourceURL)

        await store.store(
            entryURL: entryURL,
            buildStrategy: nil,
            entryVariant: .sourceInclude,
            discovery: discovery,
            configuration: .empty
        )
        try FileManager.default.removeItem(at: entryURL)

        let entry = await store.entry(
            discovery: discovery,
            configuration: .empty,
            buildStrategy: nil
        )

        #expect(entry == nil)
    }

    private func makeDiscovery(sourceFileURL: URL) -> LumiPreviewPackage.PreviewDiscovery {
        LumiPreviewPackage.PreviewDiscovery(
            id: "preview-id",
            title: "Preview",
            sourceFileURL: sourceFileURL,
            lineNumber: 1,
            endLineNumber: 3,
            primaryTypeName: "Preview",
            bodySource: "Preview()",
            sourceText: """
            #Preview {
                Preview()
            }
            """
        )
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PrewarmEntryStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
