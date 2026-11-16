import Foundation
import Testing
@testable import DatabaseManagerPlugin

/// 文本单元格编辑必须保留原始字符串（回归 #554）。
///
/// 编辑器过去对所有列统一 trim、把空串/「NULL」映射成 SQL NULL、并推断数字/布尔，
/// 导致 TEXT 列的合法内容被静默改写：`  padded  `→`padded`、`NULL`→SQL NULL、
/// `00123`→整数 123（丢前导零）、空串→SQL NULL。文本列须原样保留输入；NULL 由
/// 独立的「Set NULL」菜单提供。数值/布尔/未知列沿用既有推断，不被破坏。
@MainActor
@Suite("文本单元格编辑保留原始值")
struct TableChangeManagerTextEditTests {

    private func makeManager(
        _ columns: [(name: String, type: String, pk: Bool)]
    ) -> TableChangeManager {
        let table = DatabaseObject(kind: .table, name: "t", schema: nil)
        let cols = columns.enumerated().map { idx, c in
            TableColumn(
                name: c.name,
                dataType: c.type,
                isNullable: !c.pk,
                isPrimaryKey: c.pk,
                defaultValue: nil,
                position: idx
            )
        }
        return TableChangeManager(table: table, schema: TableSchema(table: table, columns: cols))
    }

    private func textManager() -> TableChangeManager {
        makeManager([("id", "integer", true), ("name", "text", false)])
    }

    @Test("TEXT 列保留首尾空白，不被 trim（回归 #554）")
    func textColumnPreservesPaddedWhitespace() {
        let manager = textManager()
        #expect(manager.parseEditedValue("  padded  ", column: "name") == .string("  padded  "))
    }

    @Test("TEXT 列的字面量 NULL 保留为字符串，不映射成 SQL NULL（回归 #554）")
    func textColumnPreservesLiteralNULL() {
        let manager = textManager()
        #expect(manager.parseEditedValue("NULL", column: "name") == .string("NULL"))
        #expect(manager.parseEditedValue("null", column: "name") == .string("null"))
    }

    @Test("TEXT 列保留前导零，不被推断成整数（回归 #554）")
    func textColumnPreservesLeadingZeros() {
        let manager = textManager()
        #expect(manager.parseEditedValue("00123", column: "name") == .string("00123"))
    }

    @Test("TEXT 列的空串保留为空字符串，不映射成 SQL NULL（回归 #554）")
    func textColumnPreservesEmptyString() {
        let manager = textManager()
        #expect(manager.parseEditedValue("", column: "name") == .string(""))
    }

    @Test("TEXT 列编辑生成的 UPDATE 把值内联为字符串字面量而非整数（回归 #554）")
    func textColumnUpdateGeneratesStringLiteral() {
        let manager = textManager()
        let value = manager.parseEditedValue("00123", column: "name")
        manager.stageCellUpdate(
            column: "name",
            newValue: value,
            rowValues: [.integer(1), .string("old")],
            columns: ["id", "name"]
        )
        #expect(manager.generatedUpdateStatements(for: .mysql) == ["UPDATE `t` SET `name` = '00123' WHERE `id` = 1;"])
    }

    @Test("数值/布尔列仍按类型推断，空串与 NULL 仍映射 SQL NULL（无回归）")
    func numericAndBooleanColumnsStillInferTypes() {
        let manager = makeManager([
            ("id", "integer", true), ("amount", "real", false), ("flag", "boolean", false),
        ])
        #expect(manager.parseEditedValue("123", column: "id") == .integer(123))
        #expect(manager.parseEditedValue("1.5", column: "amount") == .double(1.5))
        #expect(manager.parseEditedValue("true", column: "flag") == .bool(true))
        #expect(manager.parseEditedValue("NULL", column: "id") == .null)
        #expect(manager.parseEditedValue("", column: "amount") == .null)
    }

    @Test("各方言文本类型变体都保留原始字符串，数值/布尔类型不算文本")
    func textTypeVariantsPreserveRawString() {
        for type in ["TEXT", "VARCHAR(255)", "NVARCHAR", "CHAR(10)", "CLOB", "JSON", "UUID", "ENUM"] {
            #expect(parseEditedCellValue("00123", columnType: type) == .string("00123"), "\(type) 应视为文本")
            #expect(parseEditedCellValue("NULL", columnType: type) == .string("NULL"), "\(type) 应视为文本")
        }
        #expect(!isTextColumnType("INTEGER"))
        #expect(!isTextColumnType("BOOLEAN"))
        #expect(!isTextColumnType("DOUBLE PRECISION"))
        #expect(!isTextColumnType("BLOB"))
    }

    @Test("未知/缺省列类型沿用既有推断，不破坏无 schema 的调用方（无回归）")
    func unknownColumnTypeFallsBackToInference() {
        #expect(parseEditedCellValue("123") == .integer(123))
        #expect(parseEditedCellValue("  x  ") == .string("x"))
        #expect(parseEditedCellValue("NULL") == .null)
        #expect(parseEditedCellValue("123", columnType: nil) == .integer(123))
    }
}