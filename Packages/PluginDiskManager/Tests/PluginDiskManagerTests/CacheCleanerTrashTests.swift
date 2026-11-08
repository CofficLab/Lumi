import Foundation
import Testing
@testable import PluginDiskManager

/// 回归 #737：清空废纸篓只能删除 `~/.Trash` 的子项，不能把目录根本身交给清理。
@Suite("CacheCleanerTrash")
struct CacheCleanerTrashTests {

    private func makeTemporaryHome() throws -> URL {
        let home = FileManager.default.temporaryDirectory
            .appendingPathComponent("disk-trash-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        return home
    }

    private func makeTrashRule(home: URL) -> CacheCleanerService.CacheScanRule {
        .init(
            level: .safe,
            id: "trash",
            name: "Trash",
            desc: "Empty files in the trash",
            icon: "trash",
            paths: [home.appendingPathComponent(".Trash").path]
        )
    }

    @Test("扫描废纸篓时枚举子项，不生成指向 ~/.Trash 本身的清理项")
    func scanExpandsTrashIntoChildren() async throws {
        let home = try makeTemporaryHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let trash = home.appendingPathComponent(".Trash", isDirectory: true)
        try FileManager.default.createDirectory(at: trash, withIntermediateDirectories: true)
        try Data(repeating: 0x41, count: 128).write(to: trash.appendingPathComponent("a.txt"))
        try Data(repeating: 0x42, count: 64).write(to: trash.appendingPathComponent("b.txt"))

        let category = await CacheCleanerService.scanCategory(rule: makeTrashRule(home: home))

        let paths = try #require(category?.paths)
        #expect(paths.count == 2)
        #expect(paths.allSatisfy { $0.path != trash.path }, "根目录本身绝不能被列为可清理项")
        #expect(paths.contains { $0.path.hasSuffix("/a.txt") })
        #expect(paths.contains { $0.path.hasSuffix("/b.txt") })
    }

    @Test("清理扫描结果后废纸篓目录仍在，只删除内部文件")
    func cleanupKeepsTrashRoot() async throws {
        let home = try makeTemporaryHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let trash = home.appendingPathComponent(".Trash", isDirectory: true)
        try FileManager.default.createDirectory(at: trash, withIntermediateDirectories: true)
        let victim = trash.appendingPathComponent("victim.txt")
        try Data(repeating: 0x43, count: 256).write(to: victim)

        let category = await CacheCleanerService.scanCategory(rule: makeTrashRule(home: home))
        let paths = try #require(category?.paths)

        let freed = try await CacheCleanerService.shared.cleanup(paths: paths)

        #expect(freed == 256)
        var isDirectory: ObjCBool = false
        #expect(
            FileManager.default.fileExists(atPath: trash.path, isDirectory: &isDirectory),
            "~/.Trash 目录必须保留"
        )
        #expect(isDirectory.boolValue)
        #expect(!FileManager.default.fileExists(atPath: victim.path))
    }
}
