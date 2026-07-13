import Foundation
@testable import LumiCoreKit
import Testing

// MARK: - LumiCore 实例化存储路径测试
//
// 重构说明：
// - 旧测试通过 `AppConfig.configure(dataRootDirectory:)` 验证全局配置（已迁移至 `LumiCore` 实例）
// - `LumiStorageMigration` 相关测试已删除——迁移逻辑在新版本中不再需要
//   （参见 commit 9696785a2：「Remove LumiStorageMigration as migration is no longer needed」）
// - 新测试直接验证 `LumiCore.configure(dataRootDirectory:)` 后 `pluginDataDirectory(for:)` 的行为

@MainActor
@Test func lumiCoreConfigureMakesPluginDataDirectoryUnderDataRoot() throws {
    let tempRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("LumiCoreStorage-\(UUID().uuidString)", isDirectory: true)
    let dataRoot = tempRoot.appendingPathComponent("db_debug_v4", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: tempRoot)
    }

    let core = LumiCore()
    try core.configure(dataRootDirectory: dataRoot)

    let pluginDirectory = core.pluginDataDirectory(for: "Memory")
    #expect(pluginDirectory.lastPathComponent == "Memory")
    #expect(pluginDirectory.deletingLastPathComponent().standardizedFileURL == dataRoot.standardizedFileURL)
}

@MainActor
@Test func lumiCorePluginDataDirectorySanitizesPluginName() throws {
    let tempRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("LumiCoreStorage-\(UUID().uuidString)", isDirectory: true)
    let dataRoot = tempRoot.appendingPathComponent("db_debug_v4", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: tempRoot)
    }

    let core = LumiCore()
    try core.configure(dataRootDirectory: dataRoot)

    // 含特殊字符的插件名会被清洗
    let directory = core.pluginDataDirectory(for: "Projects Plugin!")
    #expect(directory.lastPathComponent == "Projects_Plugin")
    #expect(directory.deletingLastPathComponent().standardizedFileURL == dataRoot.standardizedFileURL)
}

@MainActor
@Test func lumiCoreCoreDataDirectoryLivesAlongsidePlugins() throws {
    let tempRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("LumiCoreStorage-\(UUID().uuidString)", isDirectory: true)
    let dataRoot = tempRoot.appendingPathComponent("db_debug_v4", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: tempRoot)
    }

    let core = LumiCore()
    try core.configure(dataRootDirectory: dataRoot)

    #expect(core.coreDataDirectory.standardizedFileURL == dataRoot.appendingPathComponent("Core", isDirectory: true).standardizedFileURL)
}

@MainActor
@Test func lumiCoreInstancesAreIndependent() throws {
    let tempRootA = FileManager.default.temporaryDirectory
        .appendingPathComponent("LumiCoreStorageA-\(UUID().uuidString)", isDirectory: true)
    let tempRootB = FileManager.default.temporaryDirectory
        .appendingPathComponent("LumiCoreStorageB-\(UUID().uuidString)", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: tempRootA)
        try? FileManager.default.removeItem(at: tempRootB)
    }

    let dataRootA = tempRootA.appendingPathComponent("db_debug_v4", isDirectory: true)
    let dataRootB = tempRootB.appendingPathComponent("db_debug_v4", isDirectory: true)

    let coreA = LumiCore()
    let coreB = LumiCore()

    try coreA.configure(dataRootDirectory: dataRootA)
    try coreB.configure(dataRootDirectory: dataRootB)

    #expect(coreA.coreDataDirectory.standardizedFileURL == dataRootA.appendingPathComponent("Core", isDirectory: true).standardizedFileURL)
    #expect(coreB.coreDataDirectory.standardizedFileURL == dataRootB.appendingPathComponent("Core", isDirectory: true).standardizedFileURL)
}