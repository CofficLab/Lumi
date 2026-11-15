import Foundation
import Testing
@testable import DatabaseManagerPlugin

/// 字符串字面量的方言转义（回归 #582）。
///
/// MySQL 默认开启反斜杠转义（NO_BACKSLASH_ESCAPES 关闭），只转义单引号会把用户
/// 输入的 `\n`/`\t`/`\0` 静默改写成控制字符，保存后内容与编辑器所见不一致。
/// SQLite/PostgreSQL 标准字符串里反斜杠是普通字符，不能额外转义。
@MainActor
@Suite("字符串字面量的方言转义")
struct TableChangeManagerStringEscapeTests {

    private func makeManager(pkType: String = "integer") -> TableChangeManager {
        let table = DatabaseObject(kind: .table, name: "t", schema: nil)
        let id = TableColumn(
            name: "id",
            dataType: pkType,
            isNullable: false,
            isPrimaryKey: true,
            defaultValue: nil,
            position: 0
        )
        let name = TableColumn(
            name: "name",
            dataType: "text",
            isNullable: true,
            isPrimaryKey: false,
            defaultValue: nil,
            position: 1
        )
        return TableChangeManager(table: table, schema: TableSchema(table: table, columns: [id, name]))
    }

    @Test("MySQL 字符串必须转义反斜杠，逐字节保留用户输入（回归 #582）")
    func mysqlStringEscapesBackslash() {
        let literal = sqlLiteral(for: .string("C:\\new\\test"), dialect: .mysql)
        #expect(literal == "'C:\\\\new\\\\test'")
    }

    @Test("MySQL 字符串同时含单引号与反斜杠时两者都正确转义")
    func mysqlStringEscapesQuoteAndBackslash() {
        let literal = sqlLiteral(for: .string("a\\'b"), dialect: .mysql)
        #expect(literal == "'a\\\\''b'")
    }

    @Test("SQLite/PostgreSQL 标准串不转义反斜杠，只转义单引号")
    func standardDialectsKeepBackslashLiteral() {
        #expect(sqlLiteral(for: .string("C:\\new\\test"), dialect: .sqlite) == "'C:\\new\\test'")
        #expect(sqlLiteral(for: .string("C:\\new\\test"), dialect: .postgresql) == "'C:\\new\\test'")
        #expect(sqlLiteral(for: .string("it's"), dialect: .postgresql) == "'it''s'")
    }

    @Test("MySQL UPDATE 语句对含反斜杠的单元格值正确转义")
    func mysqlUpdateEscapesBackslash() {
        let manager = makeManager()
        manager.stageCellUpdate(
            column: "name",
            newValue: .string("C:\\new\\test"),
            rowValues: [.integer(1), .string("old")],
            columns: ["id", "name"]
        )
        #expect(manager.generatedUpdateStatements(for: .mysql) == ["UPDATE `t` SET `name` = 'C:\\\\new\\\\test' WHERE `id` = 1;"])
    }

    @Test("MySQL INSERT 语句对含反斜杠的字符串正确转义")
    func mysqlInsertEscapesBackslash() {
        let manager = makeManager()
        let insertId = manager.addInsert()
        manager.setInsertColumn(insertId: insertId, column: "name", value: .string("path\\to"))
        #expect(manager.generatedInsertStatements(for: .mysql) == ["INSERT INTO `t` (`name`) VALUES ('path\\\\to');"])
    }

    @Test("MySQL DELETE 的主键字符串含反斜杠时也正确转义")
    func mysqlDeleteEscapesBackslashInPrimaryKey() {
        let manager = makeManager(pkType: "text")
        manager.toggleRowDeletion(rowValues: [.string("k\\1"), .string("v")], columns: ["id", "name"])
        #expect(manager.generatedDeleteStatements(for: .mysql) == ["DELETE FROM `t` WHERE `id` = 'k\\\\1';"])
    }
}