import Foundation
import Testing
@testable import DatabaseManagerPlugin

/// 按 SQL 前缀下发不同结果的假 MySQL 连接：覆盖 `describeTable` 需要的三类查询。
private actor ScriptedMySQLConnection: DatabaseConnection {
    func query(_ sql: String, params: [DatabaseValue]?) async throws -> QueryResult {
        let trimmed = sql.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if trimmed.hasPrefix("SELECT COLUMN_NAME") {
            // information_schema.columns: name, type, nullable, default, key, comment, ordinal
            return QueryResult(
                columns: ["COLUMN_NAME", "DATA_TYPE", "IS_NULLABLE", "COLUMN_DEFAULT", "COLUMN_KEY", "COLUMN_COMMENT", "ORDINAL_POSITION"],
                rows: [
                    [.string("id"), .string("INT"), .string("NO"), .null, .string("PRI"), .null, .integer(1)],
                    [.string("name"), .string("TEXT"), .string("YES"), .null, .string(""), .null, .integer(2)],
                    [.string("age"), .string("INT"), .string("YES"), .null, .string(""), .null, .integer(3)],
                    [.string("email"), .string("VARCHAR(255)"), .string("YES"), .null, .string(""), .null, .integer(4)],
                    [.string("body"), .string("TEXT"), .string("YES"), .null, .string(""), .null, .integer(5)],
                ],
                rowsAffected: 0
            )
        }
        if trimmed.hasPrefix("SHOW INDEX") {
            // SHOW INDEX 行：0 Table、1 Non_unique、2 Key_name、3 Seq_in_index、4 Column_name、10 Index_type。
            func indexRow(_ nonUnique: Int, _ key: String, _ seq: Int, _ column: String?, _ type: String) -> [DatabaseValue] {
                var row = [DatabaseValue].init(repeating: .null, count: 11)
                row[0] = .string("t")
                row[1] = .integer(nonUnique)
                row[2] = .string(key)
                row[3] = .integer(seq)
                if let column { row[4] = .string(column) }
                row[10] = .string(type)
                return row
            }
            return QueryResult(
                columns: [],
                rows: [
                    indexRow(0, "PRIMARY", 1, "id", "BTREE"),
                    indexRow(1, "idx_name", 1, "name", "BTREE"),
                    indexRow(1, "idx_name", 2, "age", "BTREE"),
                    indexRow(0, "idx_email", 1, "email", "BTREE"),
                    indexRow(1, "ft_body", 1, "body", "FULLTEXT"),
                ],
                rowsAffected: 0
            )
        }
        if trimmed.hasPrefix("SHOW CREATE TABLE") {
            return QueryResult(columns: ["Table", "Create Table"], rows: [[.string("t"), .string("CREATE TABLE `t` (...)")]], rowsAffected: 0)
        }
        return QueryResult(columns: [], rows: [], rowsAffected: 0)
    }

    func execute(_ sql: String, params: [DatabaseValue]?) async throws -> Int { 0 }
    func beginTransaction() async throws -> any DatabaseTransaction { ScriptedMySQLTransaction() }
    func close() async {}
    func isAlive() async -> Bool { true }
}

private struct ScriptedMySQLTransaction: DatabaseTransaction {
    func commit() async throws {}
    func rollback() async throws {}
    func execute(_ sql: String, params: [DatabaseValue]?) async throws -> Int { 0 }
}

@Suite("MySQL 表结构自省读取已有索引")
struct SchemaIntrospectionMySQLTests {
    private static func makeTable() -> DatabaseObject {
        DatabaseObject(kind: .table, name: "t", database: "app")
    }

    @Test("describeTable 必须用 SHOW INDEX 还原全部已有索引（#584）")
    func describeTablePopulatesIndexesFromShowIndex() async throws {
        let schema = try await MySQLIntrospector().describeTable(Self.makeTable(), in: ScriptedMySQLConnection())
        let names = schema.indexes.map(\.name)
        #expect(names == ["PRIMARY", "idx_name", "idx_email", "ft_body"])

        let primary = try #require(schema.indexes.first { $0.name == "PRIMARY" })
        #expect(primary.columns == ["id"])
        #expect(primary.isUnique)

        let composite = try #require(schema.indexes.first { $0.name == "idx_name" })
        #expect(composite.columns == ["name", "age"])
        #expect(!composite.isUnique)

        let email = try #require(schema.indexes.first { $0.name == "idx_email" })
        #expect(email.isUnique)

        let fulltext = try #require(schema.indexes.first { $0.name == "ft_body" })
        #expect(fulltext.indexType == "FULLTEXT")
    }

    @Test("基于真实索引集，新增同名索引被本地重名校验拒绝（#584）")
    @MainActor
    func existingIndexNameBlocksAddIndex() async throws {
        let schema = try await MySQLIntrospector().describeTable(Self.makeTable(), in: ScriptedMySQLConnection())
        let manager = SchemaChangeManager(table: Self.makeTable(), columns: schema.columns, indexes: schema.indexes)
        await #expect(throws: SchemaChangeValidationError.duplicateIndex("idx_name")) {
            try manager.stageAddIndex(NewTableIndexDraft(name: "idx_name", columns: ["name"]))
        }
    }

    @Test("已有索引可被暂存删除，主键索引受保护（#584）")
    @MainActor
    func existingIndexCanBeDroppedWhilePrimaryIsProtected() async throws {
        let schema = try await MySQLIntrospector().describeTable(Self.makeTable(), in: ScriptedMySQLConnection())
        let manager = SchemaChangeManager(table: Self.makeTable(), columns: schema.columns, indexes: schema.indexes)
        let composite = try #require(schema.indexes.first { $0.name == "idx_name" })
        try manager.stageDropIndex(composite)
        #expect(manager.changes.contains { if case .dropIndex(_, let index) = $0 { return index.name == "idx_name" }; return false })

        let primary = try #require(schema.indexes.first { $0.name == "PRIMARY" })
        await #expect(throws: SchemaChangeValidationError.protectedIndex("PRIMARY")) {
            try manager.stageDropIndex(primary)
        }
    }
}
