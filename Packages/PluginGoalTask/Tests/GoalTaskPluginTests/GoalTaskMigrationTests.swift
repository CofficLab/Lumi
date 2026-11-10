import Foundation
import KernelCore
import Testing
@testable import GoalTaskPlugin

@MainActor
@Suite("GoalTask Migration")
struct GoalTaskMigrationTests {

    @Test func v5MigrationLandsDatabaseAtReadPath() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("GoalTaskMigration-\(UUID())")
        defer { try? fileManager.removeItem(at: root) }

        let legacyRoot = root.appendingPathComponent("v5", isDirectory: true)
        let currentRoot = root.appendingPathComponent("v6", isDirectory: true)
        // v5 实际布局：存储键 GoalTaskPlugin + GoalStateManager 追加的内层目录。
        let legacyDB = legacyRoot
            .appendingPathComponent("GoalTaskPlugin", isDirectory: true)
            .appendingPathComponent("GoalTaskPlugin", isDirectory: true)
            .appendingPathComponent("goals.sqlite")
        try fileManager.createDirectory(
            at: legacyDB.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let payload = Data("legacy-goals".utf8)
        try payload.write(to: legacyDB)

        let plugin = GoalTaskPlugin()
        let context = PluginDataMigrationContext(
            pluginID: plugin.id,
            currentMajorVersion: 6,
            currentDataRootDirectory: currentRoot,
            legacyDataRootDirectories: [5: legacyRoot]
        )
        try plugin.migrateData(context: context)

        // 回归 #767：旧库必须落在 GoalStateManager 实际读取的位置。
        let dbDir = currentRoot
            .appendingPathComponent(plugin.id, isDirectory: true)
            .appendingPathComponent("GoalTaskPlugin", isDirectory: true)
        let readPath = dbDir.appendingPathComponent("goals.sqlite")
        #expect(try Data(contentsOf: readPath) == payload)
        // 不能再套一层，否则新库会在读取位置被创建并把旧库遮住。
        let overNested = dbDir
            .appendingPathComponent("GoalTaskPlugin", isDirectory: true)
            .appendingPathComponent("goals.sqlite")
        #expect(!fileManager.fileExists(atPath: overNested.path))

        // 复制式迁移必须可重试。
        try plugin.migrateData(context: context)
        #expect(try Data(contentsOf: readPath) == payload)
    }

    @Test func v4MigrationReadsGoalTaskDirectory() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("GoalTaskV4Migration-\(UUID())")
        defer { try? fileManager.removeItem(at: root) }

        let legacyRoot = root.appendingPathComponent("v4", isDirectory: true)
        let currentRoot = root.appendingPathComponent("current", isDirectory: true)
        // v4 的数据目录是 `GoalTask`，`GoalStateManager` 仍然追加 `GoalTaskPlugin`。
        let legacyDB = legacyRoot
            .appendingPathComponent("GoalTask", isDirectory: true)
            .appendingPathComponent("GoalTaskPlugin", isDirectory: true)
            .appendingPathComponent("goals.sqlite")
        try fileManager.createDirectory(
            at: legacyDB.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let payload = Data("v4-goals".utf8)
        try payload.write(to: legacyDB)

        let plugin = GoalTaskPlugin()
        #expect(plugin.legacyDataDirectoryNames.contains("GoalTask"))
        try plugin.migrateData(context: PluginDataMigrationContext(
            pluginID: plugin.id,
            currentMajorVersion: 6,
            currentDataRootDirectory: currentRoot,
            legacyDataRootDirectories: [4: legacyRoot]
        ))

        // 回归 #768：v4 的 `GoalTask` 目录必须被识别，并落到当前读取路径。
        let dbDir = currentRoot
            .appendingPathComponent(plugin.id, isDirectory: true)
            .appendingPathComponent("GoalTaskPlugin", isDirectory: true)
        #expect(try Data(contentsOf: dbDir.appendingPathComponent("goals.sqlite")) == payload)
        #expect(!fileManager.fileExists(
            atPath: dbDir.appendingPathComponent("GoalTaskPlugin/goals.sqlite").path
        ))
    }

    @Test func promotesMisplacedStoreOnlyWhenReadPathIsEmpty() async throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("GoalTaskPromotion-\(UUID())")
        defer { try? fileManager.removeItem(at: root) }

        // 先用真实的 GoalStateManager 造一个「旧库」（数据库里有一条 Goal）。
        let legacyRoot = root.appendingPathComponent("legacy", isDirectory: true)
        let legacyManager = try GoalStateManager(databaseRootURL: legacyRoot)
        _ = try await legacyManager.createGoal(
            conversationId: "legacy-conversation",
            title: "Legacy goal",
            description: nil,
            successCriteria: nil,
            tasks: []
        )
        let legacyDBDir = legacyRoot.appendingPathComponent("GoalTaskPlugin", isDirectory: true)

        let dbDir = root.appendingPathComponent("current").appendingPathComponent("GoalTaskPlugin", isDirectory: true)
        // 旧版迁移后首次启动会在读取位置创建一个空库。
        _ = try GoalStateManager.makeContainer(databaseRootURL: root.appendingPathComponent("current", isDirectory: true))
        #expect(fileManager.fileExists(atPath: dbDir.appendingPathComponent("goals.sqlite").path))

        // 旧的错误布局：读取位置下再多一层 GoalTaskPlugin。
        let misplacedDir = dbDir.appendingPathComponent("GoalTaskPlugin", isDirectory: true)
        try fileManager.createDirectory(at: misplacedDir, withIntermediateDirectories: true)
        for suffix in ["", "-wal", "-shm"] {
            let source = URL(fileURLWithPath: legacyDBDir.appendingPathComponent("goals.sqlite").path + suffix)
            guard fileManager.fileExists(atPath: source.path) else { continue }
            try fileManager.copyItem(
                at: source,
                to: URL(fileURLWithPath: misplacedDir.appendingPathComponent("goals.sqlite").path + suffix)
            )
        }

        // 打开读取位置时必须把旧库提上来，用户才能看到原来的 Goal。
        let promoted = try GoalStateManager(databaseRootURL: root.appendingPathComponent("current", isDirectory: true))
        #expect(await promoted.fetchGoals(conversationId: "legacy-conversation").count == 1)

        // 读取位置已有数据时不能覆盖：升级后新建的 Goal 不能被旧库替换。
        let inUseRoot = root.appendingPathComponent("in-use", isDirectory: true)
        let inUseManager = try GoalStateManager(databaseRootURL: inUseRoot)
        _ = try await inUseManager.createGoal(
            conversationId: "upgraded-conversation",
            title: "Upgraded goal",
            description: nil,
            successCriteria: nil,
            tasks: []
        )
        let inUseDBDir = inUseRoot.appendingPathComponent("GoalTaskPlugin", isDirectory: true)
        let inUseDB = inUseDBDir.appendingPathComponent("goals.sqlite")
        let inUseMisplaced = inUseDBDir
            .appendingPathComponent("GoalTaskPlugin", isDirectory: true)
            .appendingPathComponent("goals.sqlite")
        try fileManager.createDirectory(
            at: inUseMisplaced.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try fileManager.copyItem(at: legacyDBDir.appendingPathComponent("goals.sqlite"), to: inUseMisplaced)

        GoalStateManager.promoteMisplacedLegacyStore(at: inUseDB)
        #expect(await inUseManager.fetchGoals(conversationId: "upgraded-conversation").count == 1)
        #expect(await inUseManager.fetchGoals(conversationId: "legacy-conversation").isEmpty)
    }
}
