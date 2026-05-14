import Foundation
import Testing
@testable import LumiHotPreviewKit

@Suite("HotSyntaxPreflightCache")
struct HotSyntaxPreflightCacheTests {
    @Test("reuses cached syntax result when source fingerprint is unchanged")
    func reusesCachedSyntaxResultWhenSourceFingerprintIsUnchanged() async throws {
        let cache = HotSyntaxPreflightCache()
        let sourceURL = try makeTemporarySwiftFile(contents: "struct Preview {}")
        let counter = Counter()

        let first = await cache.result(for: sourceURL) {
            await counter.increment()
            return .valid
        }
        let second = await cache.result(for: sourceURL) {
            await counter.increment()
            return .invalid([])
        }

        #expect(first.usedCache == false)
        #expect(second.usedCache == true)
        #expect(second.result == .valid)
        #expect(await counter.value == 1)
    }

    @Test("invalidates cached syntax result when file size changes")
    func invalidatesCachedSyntaxResultWhenFileSizeChanges() async throws {
        let cache = HotSyntaxPreflightCache()
        let sourceURL = try makeTemporarySwiftFile(contents: "struct Preview {}")
        let counter = Counter()

        _ = await cache.result(for: sourceURL) {
            await counter.increment()
            return .valid
        }
        try "struct Preview { let value = 1 }".write(to: sourceURL, atomically: true, encoding: .utf8)

        let second = await cache.result(for: sourceURL) {
            await counter.increment()
            return .invalid([.init(message: "changed")])
        }

        #expect(second.usedCache == false)
        #expect(second.result == .invalid([.init(message: "changed")]))
        #expect(await counter.value == 2)
    }

    @Test("invalidates cached syntax result when modification date changes")
    func invalidatesCachedSyntaxResultWhenModificationDateChanges() async throws {
        let cache = HotSyntaxPreflightCache()
        let sourceURL = try makeTemporarySwiftFile(contents: "struct Preview {}")
        let counter = Counter()

        _ = await cache.result(for: sourceURL) {
            await counter.increment()
            return .valid
        }
        let modifiedAt = Date(timeIntervalSince1970: Date().timeIntervalSince1970 + 10)
        try FileManager.default.setAttributes([.modificationDate: modifiedAt], ofItemAtPath: sourceURL.path)

        let second = await cache.result(for: sourceURL) {
            await counter.increment()
            return .invalid([.init(message: "mtime changed")])
        }

        #expect(second.usedCache == false)
        #expect(second.result == .invalid([.init(message: "mtime changed")]))
        #expect(await counter.value == 2)
    }

    private func makeTemporarySwiftFile(contents: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("HotSyntaxPreflightCacheTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("Preview.swift")
        try contents.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
}

private actor Counter {
    private(set) var value = 0

    func increment() {
        value += 1
    }
}
