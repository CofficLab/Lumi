import Foundation
import Testing
@testable import LumiPreviewKit

@Suite("PreviewStorageAutoCleaner")
struct PreviewStorageAutoCleanerTests {
    @Test("删除超过保留期的顶层缓存项")
    func removesExpiredTopLevelItems() throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let cache = root.appendingPathComponent("cache", isDirectory: true)
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)

        let expired = try writeFile(
            cache.appendingPathComponent("expired.bin"),
            byteCount: 16
        )
        let recent = try writeFile(
            cache.appendingPathComponent("recent.bin"),
            byteCount: 16
        )
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        try setModificationDate(now.addingTimeInterval(-15 * 24 * 60 * 60), for: expired)
        try setModificationDate(now.addingTimeInterval(-1 * 24 * 60 * 60), for: recent)

        let result = LumiPreviewFacade.PreviewStorageAutoCleaner.clean(
            directories: [cache],
            policy: .init(
                maximumAge: 14 * 24 * 60 * 60,
                maximumSizeBytes: 1024,
                targetSizeBytes: 512
            ),
            now: now
        )

        #expect(result.removedItemCount == 1)
        #expect(!FileManager.default.fileExists(atPath: expired.path))
        #expect(FileManager.default.fileExists(atPath: recent.path))
    }

    @Test("超过大小上限时从最旧缓存项裁剪到目标大小")
    func trimsOldestItemsWhenSizeLimitIsExceeded() throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let cache = root.appendingPathComponent("cache", isDirectory: true)
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)

        let oldest = try writeFile(cache.appendingPathComponent("oldest.bin"), byteCount: 60)
        let middle = try writeFile(cache.appendingPathComponent("middle.bin"), byteCount: 50)
        let newest = try writeFile(cache.appendingPathComponent("newest.bin"), byteCount: 40)

        let now = Date(timeIntervalSince1970: 1_700_000_000)
        try setModificationDate(now.addingTimeInterval(-3 * 24 * 60 * 60), for: oldest)
        try setModificationDate(now.addingTimeInterval(-2 * 24 * 60 * 60), for: middle)
        try setModificationDate(now.addingTimeInterval(-1 * 24 * 60 * 60), for: newest)

        let result = LumiPreviewFacade.PreviewStorageAutoCleaner.clean(
            directories: [cache],
            policy: .init(
                maximumAge: 365 * 24 * 60 * 60,
                maximumSizeBytes: 100,
                targetSizeBytes: 60
            ),
            now: now
        )

        #expect(result.removedItemCount == 2)
        #expect(!FileManager.default.fileExists(atPath: oldest.path))
        #expect(!FileManager.default.fileExists(atPath: middle.path))
        #expect(FileManager.default.fileExists(atPath: newest.path))
        #expect(result.remainingByteCount == 40)
    }

    private func temporaryRoot() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("PreviewStorageAutoCleanerTests-\(UUID().uuidString)", isDirectory: true)
    }

    @discardableResult
    private func writeFile(_ url: URL, byteCount: Int) throws -> URL {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(repeating: 0, count: byteCount).write(to: url)
        return url
    }

    private func setModificationDate(_ date: Date, for url: URL) throws {
        try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: url.path)
    }
}
