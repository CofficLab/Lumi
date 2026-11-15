import Foundation
import Testing
@testable import DatabaseManagerPlugin

/// BLOB 主键的二进制字面量（回归 #567）。
///
/// 驱动把 BLOB 列解码为 `.data`，旧 `sqlLiteral` 对 `.data` 恒生成 `NULL`，
/// 于是 BLOB 主键行的 UPDATE/DELETE WHERE 变成 `pk = NULL`，永不匹配、命中 0 行，
/// 保存却报成功并清空暂存。修复：按方言内联正确的二进制字面量
/// （SQLite/MySQL `X'…'`、PostgreSQL `decode('…','hex')`）。
/// BLOB 单元格编辑本身仍只读（#281），此处只解决「以 BLOB 主键定位行」。
@MainActor
@Suite("BLOB 主键的二进制字面量")
struct TableChangeManagerBlobPrimaryKeyTests {

    private func filesManager() -> TableChangeManager {
        let table = DatabaseObject(kind: .table, name: "files", schema: nil)
        let columns = [
            TableColumn(name: "id", dataType: "blob", isNullable: false, isPrimaryKey: true, defaultValue: nil, position: 0),
            TableColumn(name: "name", dataType: "text", isNullable: true, isPrimaryKey: false, defaultValue: nil, position: 1),
        ]
        return TableChangeManager(table: table, schema: TableSchema(table: table, columns: columns))
    }

    private let row: [DatabaseValue] = [.data(Data([0x01])), .string("before")]
    private let columns = ["id", "name"]

    // MARK: - 字面量生成

    @Test("SQLite/MySQL 的 BLOB 字面量为 X'十六进制'")
    func blobLiteralUsesHexForSQLiteAndMySQL() {
        let value = DatabaseValue.data(Data([0x01, 0x02]))
        #expect(sqlLiteral(for: value, dialect: .sqlite) == "X'0102'")
        #expect(sqlLiteral(for: value, dialect: .mysql) == "X'0102'")
    }

    @Test("PostgreSQL 的 BLOB 字面量为 decode('十六进制','hex')")
    func blobLiteralUsesDecodeForPostgreSQL() {
        #expect(sqlLiteral(for: .data(Data([0x01, 0x02])), dialect: .postgresql) == "decode('0102', 'hex')")
    }

    @Test("空 BLOB 生成合法的空二进制字面量")
    func emptyBlobLiteralIsValid() {
        #expect(sqlLiteral(for: .data(Data()), dialect: .sqlite) == "X''")
        #expect(sqlLiteral(for: .data(Data()), dialect: .postgresql) == "decode('', 'hex')")
    }

    @Test("BLOB 主键行的 UPDATE 用二进制字面量而非 NULL")
    func blobPrimaryKeyUpdateUsesHexLiteral() {
        let cm = filesManager()
        cm.stageCellUpdate(column: "name", newValue: .string("after"), rowValues: row, columns: columns)
        #expect(cm.generatedUpdateStatements(for: .sqlite) == ["UPDATE \"files\" SET \"name\" = 'after' WHERE \"id\" = X'01';"])
        #expect(cm.generatedUpdateStatements(for: .mysql) == ["UPDATE `files` SET `name` = 'after' WHERE `id` = X'01';"])
    }

    @Test("BLOB 主键行的 DELETE 用二进制字面量而非 NULL")
    func blobPrimaryKeyDeleteUsesHexLiteral() {
        let cm = filesManager()
        cm.toggleRowDeletion(rowValues: row, columns: columns)
        #expect(cm.generatedDeleteStatements(for: .sqlite) == ["DELETE FROM \"files\" WHERE \"id\" = X'01';"])
    }

    // MARK: - SQLite 端到端

    @Test("BLOB 主键行的 UPDATE 在真实 SQLite 上命中并修改该行")
    func blobPrimaryKeyUpdateActuallyModifiesRow() async throws {
        let path = NSTemporaryDirectory() + "/lumi-blobpk-\(UUID().uuidString).sqlite"
        defer { try? FileManager.default.removeItem(atPath: path) }
        let connection = try await SQLiteDriver().connect(config: DatabaseConfig(name: "BlobPK", type: .sqlite, database: path))
        _ = try await connection.execute("CREATE TABLE files(id BLOB PRIMARY KEY, name TEXT)", params: nil)
        _ = try await connection.execute("INSERT INTO files VALUES (x'01', 'before')", params: nil)

        let cm = filesManager()
        cm.stageCellUpdate(column: "name", newValue: .string("after"), rowValues: row, columns: columns)
        for sql in cm.generatedUpdateStatements(for: .sqlite) {
            let affected = try await connection.execute(sql, params: nil)
            #expect(affected == 1)
        }
        let result = try await connection.query("SELECT name FROM files", params: nil)
        #expect(result.rows == [[.string("after")]])
        await connection.close()
    }

    @Test("BLOB 主键行的 DELETE 在真实 SQLite 上命中并删除该行")
    func blobPrimaryKeyDeleteActuallyRemovesRow() async throws {
        let path = NSTemporaryDirectory() + "/lumi-blobpk-\(UUID().uuidString).sqlite"
        defer { try? FileManager.default.removeItem(atPath: path) }
        let connection = try await SQLiteDriver().connect(config: DatabaseConfig(name: "BlobPK", type: .sqlite, database: path))
        _ = try await connection.execute("CREATE TABLE files(id BLOB PRIMARY KEY, name TEXT)", params: nil)
        _ = try await connection.execute("INSERT INTO files VALUES (x'01', 'before')", params: nil)

        let cm = filesManager()
        cm.toggleRowDeletion(rowValues: row, columns: columns)
        for sql in cm.generatedDeleteStatements(for: .sqlite) {
            let affected = try await connection.execute(sql, params: nil)
            #expect(affected == 1)
        }
        let count = try await connection.query("SELECT count(*) FROM files", params: nil)
        #expect(count.rows.first?.first == .integer(0))
        await connection.close()
    }
}