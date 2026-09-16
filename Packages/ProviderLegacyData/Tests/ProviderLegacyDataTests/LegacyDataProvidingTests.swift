import Foundation
import Testing
@testable import ProviderLegacyData

@MainActor
@Test("未配置旧数据目录时不报告旧数据")
func missingLegacyRootHasNoLegacyData() {
    let provider = DefaultLegacyDataProviding()

    #expect(provider.legacyDataRootDirectory == nil)
    #expect(!provider.hasLegacyData())
}

@MainActor
@Test("旧数据目录不存在时返回 false，目录创建后返回 true")
func legacyDataPresenceTracksFilesystem() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("legacy-data-\(UUID().uuidString)", isDirectory: true)
    let provider = DefaultLegacyDataProviding(root: root)
    defer { try? FileManager.default.removeItem(at: root) }

    #expect(provider.legacyDataRootDirectory == root)
    #expect(!provider.hasLegacyData())

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

    #expect(provider.hasLegacyData())
}

@MainActor
@Test("已存在的普通文件路径也会被视为存在的旧数据路径")
func existingLegacyFileIsDetected() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("legacy-data-file-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    try Data("snapshot".utf8).write(to: root)
    let provider = DefaultLegacyDataProviding(root: root)

    #expect(provider.hasLegacyData())
}

@MainActor
@Test("释放旧快照接口可安全调用")
func releasingLegacySnapshotIsSafe() {
    DefaultLegacyDataProviding().releaseLegacySnapshot()
}
