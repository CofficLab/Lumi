import Foundation
import Testing
@testable import DatabaseManagerPlugin

/// 回归 #561 / #560：结构编辑暂存层对「同一对象的重复操作」必须收敛为单条 DDL。
///
/// #561：同一原始索引的删除被重复暂存时，不得生成第二条 `DROP INDEX`——否则保存时
/// 第二条找不到索引，整个 DDL 事务回滚。`stageDropIndex` 先按名移除旧条目再追加，
/// 净结果至多一条。
/// #560：同一原列连续两次重命名必须折叠为单条 `RENAME`（old → final），不得生成两条
/// 都从原列名出发的 `ALTER ... RENAME COLUMN`——否则第二条找不到列、事务回滚。
/// `stageRename` 先按 oldName 移除旧条目再追加，净结果至多一条。
@MainActor
@Suite("结构变更暂存幂等")
struct SchemaChangeStagingIdempotencyTests {

    private func makeManager(indexes: [TableIndex] = []) -> SchemaChangeManager {
        let table = DatabaseObject(kind: .table, name: "t", schema: nil)
        let columns = [
            TableColumn(name: "id", dataType: "integer", isNullable: false, isPrimaryKey: true, defaultValue: nil, position: 0),
            TableColumn(name: "old_name", dataType: "text", isNullable: true, isPrimaryKey: false, defaultValue: nil, position: 1),
            TableColumn(name: "other", dataType: "text", isNullable: true, isPrimaryKey: false, defaultValue: nil, position: 2),
        ]
        return SchemaChangeManager(table: table, columns: columns, indexes: indexes)
    }

    private func dropIndexChanges(_ manager: SchemaChangeManager) -> [PendingSchemaChange] {
        manager.changes.filter { if case .dropIndex = $0 { return true }; return false }
    }

    private func renameChanges(_ manager: SchemaChangeManager) -> [PendingSchemaChange] {
        manager.changes.filter { if case .renameColumn = $0 { return true }; return false }
    }

    // MARK: - #561 索引删除幂等

    @Test("重复暂存同一索引删除只生成一条 DROP INDEX（**回归 #561**）")
    func repeatedIndexDropStagesOnce() throws {
        let index = TableIndex(name: "idx_old", columns: ["old_name"], isUnique: false)
        let manager = makeManager(indexes: [index])

        try manager.stageDropIndex(index)
        try manager.stageDropIndex(index)

        #expect(dropIndexChanges(manager).count == 1, "同一索引的删除被暂存了多次")
        let statements = manager.statements(for: .sqlite)
        #expect(statements.count == 1)
        #expect(statements.first?.contains("DROP INDEX") == true)
        #expect(statements.first?.contains("idx_old") == true)
    }

    @Test("删除两个不同索引各自保留一条 DROP INDEX")
    func distinctIndexDropsBothStaged() throws {
        let first = TableIndex(name: "idx_a", columns: ["old_name"], isUnique: false)
        let second = TableIndex(name: "idx_b", columns: ["other"], isUnique: true)
        let manager = makeManager(indexes: [first, second])

        try manager.stageDropIndex(first)
        try manager.stageDropIndex(second)
        try manager.stageDropIndex(first)

        #expect(dropIndexChanges(manager).count == 2)
        let statements = manager.statements(for: .sqlite)
        #expect(statements.count == 2)
        #expect(statements.contains { $0.contains("idx_a") })
        #expect(statements.contains { $0.contains("idx_b") })
    }

    @Test("受保护索引仍拒绝删除，幂等收敛不放宽保护")
    func protectedIndexDropStillThrows() throws {
        let manager = makeManager()
        let primary = TableIndex(name: "primary", columns: ["id"], isUnique: true)
        #expect(throws: SchemaChangeValidationError.protectedIndex("primary")) {
            try manager.stageDropIndex(primary)
        }
        #expect(manager.changes.isEmpty)
    }

    // MARK: - #560 列重命名折叠

    @Test("同一原列连续两次重命名折叠为单条 RENAME（**回归 #560**）")
    func repeatedRenameFoldsToSingleStatement() throws {
        let manager = makeManager()
        let column = try #require(manager.originalColumns.first { $0.name == "old_name" })

        try manager.stageRename(column, to: "middle_name")
        try manager.stageRename(column, to: "final_name")

        #expect(renameChanges(manager).count == 1, "同一原列的重命名被暂存了多次")
        let statements = manager.statements(for: .sqlite)
        #expect(statements.count == 1)
        let statement = try #require(statements.first)
        #expect(statement.contains("RENAME COLUMN"))
        #expect(statement.contains("old_name"))
        #expect(statement.contains("final_name"))
        #expect(!statement.contains("middle_name"), "应直接折叠为 old_name → final_name")
    }

    @Test("从已暂存的新名再次重命名生成顺序有效的链式 DDL")
    func renameFromPendingNameChainsValidDDL() throws {
        let manager = makeManager()
        let column = try #require(manager.originalColumns.first { $0.name == "old_name" })
        try manager.stageRename(column, to: "middle_name")

        let pending = TableColumn(name: "middle_name", dataType: "text", isNullable: true, isPrimaryKey: false, defaultValue: nil, position: 1)
        try manager.stageRename(pending, to: "final_name")

        let statements = manager.statements(for: .sqlite)
        #expect(statements.count == 2)
        #expect(statements[0].contains("old_name"))
        #expect(statements[0].contains("middle_name"))
        #expect(statements[1].contains("middle_name"))
        #expect(statements[1].contains("final_name"))
    }

    @Test("重命名两个不同列各自保留一条 RENAME")
    func distinctColumnRenamesBothStaged() throws {
        let manager = makeManager()
        let first = try #require(manager.originalColumns.first { $0.name == "old_name" })
        let second = try #require(manager.originalColumns.first { $0.name == "other" })

        try manager.stageRename(first, to: "renamed_a")
        try manager.stageRename(second, to: "renamed_b")

        #expect(renameChanges(manager).count == 2)
        let statements = manager.statements(for: .sqlite)
        #expect(statements.count == 2)
        #expect(statements.contains { $0.contains("renamed_a") })
        #expect(statements.contains { $0.contains("renamed_b") })
    }
}