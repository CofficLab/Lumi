import Foundation
import Testing
@testable import DatabaseManagerPlugin

/// BLOB 单元格在 v1 视为只读：提交占位文本不得覆盖原始二进制。
///
/// ## 回归背景（真实用户缺陷 #281）
///
/// 双击 BLOB 单元格会把显示占位符 `<BLOB N bytes>` 填入编辑器，未改内容直接回车
/// 保存时，`parseEditedCellValue` 把占位符当普通字符串暂存，`sqlLiteral` 再内联成
/// 字符串字面量，原始字节被破坏。变更跟踪层必须在暂存前拒绝对二进制单元格的修改。
@MainActor
@Suite("BLOB 单元格只读")
struct TableChangeManagerBlobEditTests {

    /// 造一张带主键的表 `t(id PK, b BLOB, name TEXT)`，返回其变更跟踪器。
    private func makeManager() -> TableChangeManager {
        let table = DatabaseObject(kind: .table, name: "t", schema: nil)
        let columns = [
            TableColumn(name: "id", dataType: "integer", isNullable: false, isPrimaryKey: true, defaultValue: nil, position: 0),
            TableColumn(name: "b", dataType: "blob", isNullable: true, isPrimaryKey: false, defaultValue: nil, position: 1),
            TableColumn(name: "name", dataType: "text", isNullable: true, isPrimaryKey: false, defaultValue: nil, position: 2),
        ]
        return TableChangeManager(table: table, schema: TableSchema(table: table, columns: columns))
    }

    private let columns = ["id", "b", "name"]
    private var row: [DatabaseValue] { [.integer(1), .data(Data([0x01])), .string("Alice")] }

    @Test("提交 BLOB 占位文本不产生任何变更，原始二进制保留（回归 #281）")
    func blobPlaceholderCommitStagesNoChange() {
        let manager = makeManager()

        manager.stageCellUpdate(column: "b", newValue: .string("<BLOB 1 bytes>"), rowValues: row, columns: columns)

        #expect(!manager.hasChanges)
        #expect(manager.changedCellCount == 0)
        #expect(manager.generatedUpdateStatements(for: .sqlite).isEmpty)
        #expect(manager.displayedValue(column: "b", rowValues: row, columns: columns) == .data(Data([0x01])))
    }

    @Test("同一行的非 BLOB 列仍可正常编辑，只读限制按单元格生效")
    func nonBlobCellInSameRowStillStages() {
        let manager = makeManager()

        manager.stageCellUpdate(column: "name", newValue: .string("Bob"), rowValues: row, columns: columns)

        #expect(manager.hasChanges)
        #expect(manager.changedCellCount == 1)
        #expect(manager.isCellChanged(column: "name", rowValues: row, columns: columns))
        #expect(!manager.isCellChanged(column: "b", rowValues: row, columns: columns))
    }
}