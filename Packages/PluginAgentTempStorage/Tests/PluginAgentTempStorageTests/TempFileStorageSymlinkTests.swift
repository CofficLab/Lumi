import Foundation
import Testing
@testable import PluginAgentTempStorage

/// 临时存储的边界检查必须解析符号链接：目录内指向外部的链接
/// 不得让 read/write 越界读写（回归 #232）。
@MainActor
struct TempFileStorageSymlinkTests {

    private func makeStorageWithOutside() throws -> (container: URL, storage: URL, outside: URL) {
        let container = FileManager.default.temporaryDirectory
            .appendingPathComponent("PluginAgentTempStorageSymlinkTests-\(UUID().uuidString)", isDirectory: true)
        let storage = container.appendingPathComponent("storage", isDirectory: true)
        let outside = container.appendingPathComponent("outside", isDirectory: true)
        try FileManager.default.createDirectory(at: storage, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        return (container, storage, outside)
    }

    @Test
    func writeRejectsFileSymlinkPointingOutsideStorage() async throws {
        let (container, storage, outside) = try makeStorageWithOutside()
        defer { try? FileManager.default.removeItem(at: container) }
        let service = TempFileStorageService(directory: storage, retentionDays: 7)

        let target = outside.appendingPathComponent("target.md")
        try "original".write(to: target, atomically: true, encoding: .utf8)
        try FileManager.default.createSymbolicLink(
            at: storage.appendingPathComponent("link.md"),
            withDestinationURL: target
        )

        await #expect(throws: TempFileStorageError.pathTraversal) {
            _ = try await service.write(filename: "link.md", content: "evil")
        }
        #expect(try String(contentsOf: target, encoding: .utf8) == "original")
    }

    @Test
    func readRejectsFileSymlinkPointingOutsideStorage() async throws {
        let (container, storage, outside) = try makeStorageWithOutside()
        defer { try? FileManager.default.removeItem(at: container) }
        let service = TempFileStorageService(directory: storage, retentionDays: 7)

        let target = outside.appendingPathComponent("secret.md")
        try "secret".write(to: target, atomically: true, encoding: .utf8)
        try FileManager.default.createSymbolicLink(
            at: storage.appendingPathComponent("link.md"),
            withDestinationURL: target
        )

        await #expect(throws: TempFileStorageError.pathTraversal) {
            _ = try await service.read(filename: "link.md")
        }
    }

    @Test
    func writeRejectsNestedPathThroughSymlinkDirectory() async throws {
        let (container, storage, outside) = try makeStorageWithOutside()
        defer { try? FileManager.default.removeItem(at: container) }
        let service = TempFileStorageService(directory: storage, retentionDays: 7)

        try FileManager.default.createSymbolicLink(
            at: storage.appendingPathComponent("exports"),
            withDestinationURL: outside
        )

        await #expect(throws: TempFileStorageError.pathTraversal) {
            _ = try await service.write(filename: "exports/data.json", content: "evil")
        }
        let outsideEntries = (try? FileManager.default.contentsOfDirectory(atPath: outside.path)) ?? []
        #expect(!outsideEntries.contains("data.json"))
    }

    @Test
    func writeThroughDanglingSymlinkDirectoryFailsWithoutExternalSideEffects() async throws {
        let (container, storage, outside) = try makeStorageWithOutside()
        defer { try? FileManager.default.removeItem(at: container) }
        let service = TempFileStorageService(directory: storage, retentionDays: 7)

        // 悬空链接（目标尚不存在）：resolvingSymlinksInPath 不解析它，但
        // Foundation 拒绝经悬空链接创建目录，写入必须失败且不得在外部留下任何内容。
        let missingTarget = outside.appendingPathComponent("missing", isDirectory: true)
        try FileManager.default.createSymbolicLink(
            at: storage.appendingPathComponent("exports"),
            withDestinationURL: missingTarget
        )

        await #expect(throws: (any Error).self) {
            _ = try await service.write(filename: "exports/data.json", content: "evil")
        }
        let outsideEntries = (try? FileManager.default.contentsOfDirectory(atPath: outside.path)) ?? []
        #expect(outsideEntries.isEmpty)
    }

    @Test
    func readRejectsNestedPathThroughSymlinkDirectory() async throws {
        let (container, storage, outside) = try makeStorageWithOutside()
        defer { try? FileManager.default.removeItem(at: container) }
        let service = TempFileStorageService(directory: storage, retentionDays: 7)

        let target = outside.appendingPathComponent("secret.txt")
        try "secret".write(to: target, atomically: true, encoding: .utf8)
        try FileManager.default.createSymbolicLink(
            at: storage.appendingPathComponent("exports"),
            withDestinationURL: outside
        )

        await #expect(throws: TempFileStorageError.pathTraversal) {
            _ = try await service.read(filename: "exports/secret.txt")
        }
    }

    @Test
    func symlinksStayingInsideStorageRemainUsable() async throws {
        let (container, storage, _) = try makeStorageWithOutside()
        defer { try? FileManager.default.removeItem(at: container) }
        let service = TempFileStorageService(directory: storage, retentionDays: 7)

        _ = try await service.write(filename: "real.md", content: "inside")
        try FileManager.default.createSymbolicLink(
            at: storage.appendingPathComponent("alias.md"),
            withDestinationURL: storage.appendingPathComponent("real.md")
        )

        // 指向根目录内部的链接不得被误杀。
        #expect(try await service.read(filename: "alias.md") == "inside")
        let realURL = storage.appendingPathComponent("real.md")
        #expect(try String(contentsOf: realURL, encoding: .utf8) == "inside")
    }
}