import Foundation
import Testing
@testable import DatabaseManagerPlugin

/// 空行（Add Row 未填任何值）插入语句的方言生成。
///
/// ## 回归背景（真实用户缺陷 #280）
///
/// 在 PostgreSQL 表上点 Add Row 再 Save，生成的是 MySQL 专用的
/// `INSERT INTO ... () VALUES ()`，PostgreSQL 不接受该语法，保存事务被回滚。
/// 根因是空列插入分支把 PostgreSQL 与 MySQL 合并处理；实际上 PostgreSQL 与
/// SQLite 一样支持 `INSERT INTO ... DEFAULT VALUES`，只有 MySQL 需要空列清单。
@MainActor
@Suite("空行插入语句的方言生成")
struct TableChangeManagerInsertSQLTests {

    /// 造一张带主键的表 `t`（可选 schema），返回其变更跟踪器。
    private func makeManager(schema: String? = nil) -> TableChangeManager {
        let table = DatabaseObject(kind: .table, name: "t", schema: schema)
        let column = TableColumn(
            name: "id",
            dataType: "integer",
            isNullable: false,
            isPrimaryKey: true,
            defaultValue: nil,
            position: 0
        )
        return TableChangeManager(table: table, schema: TableSchema(table: table, columns: [column]))
    }

    @Test("PostgreSQL 空行插入必须生成 DEFAULT VALUES，不得套用 MySQL 的 () VALUES ()（回归 #280）")
    func postgresEmptyInsertUsesDefaultValues() {
        let manager = makeManager()
        manager.addInsert()

        #expect(manager.generatedInsertStatements(for: .postgresql) == ["INSERT INTO \"t\" DEFAULT VALUES;"])
    }

    @Test("MySQL 空行插入仍生成空列清单 () VALUES ()")
    func mysqlEmptyInsertUsesEmptyColumnList() {
        let manager = makeManager()
        manager.addInsert()

        #expect(manager.generatedInsertStatements(for: .mysql) == ["INSERT INTO `t` () VALUES ();"])
    }

    @Test("SQLite 空行插入生成 DEFAULT VALUES")
    func sqliteEmptyInsertUsesDefaultValues() {
        let manager = makeManager()
        manager.addInsert()

        #expect(manager.generatedInsertStatements(for: .sqlite) == ["INSERT INTO \"t\" DEFAULT VALUES;"])
    }

    @Test("PostgreSQL 带 schema 的空行插入仍用 DEFAULT VALUES 且限定名正确")
    func postgresEmptyInsertWithSchemaUsesDefaultValues() {
        let manager = makeManager(schema: "public")
        manager.addInsert()

        #expect(manager.generatedInsertStatements(for: .postgresql) == ["INSERT INTO \"public\".\"t\" DEFAULT VALUES;"])
    }
}