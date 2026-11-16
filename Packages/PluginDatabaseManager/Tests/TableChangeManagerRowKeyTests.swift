import Foundation
import Testing
@testable import DatabaseManagerPlugin

/// 主键行标识必须唯一且可逆（回归 #555）。
///
/// 旧实现用 `"\(pk)=\(value.description)"` 以 `|` 拼接，无长度/类型编码与转义：
/// 复合主键里含 `|`/`=` 的字符串会错位碰撞、同长度 BLOB 都描述成 "N bytes"、
/// 数字与同形字符串也无法区分。碰撞使两行的编辑/删除状态相互覆盖，
/// 最终 UPDATE/DELETE 作用到错误的主键，造成改错行或漏删/误删。
@MainActor
@Suite("主键行标识唯一性")
struct TableChangeManagerRowKeyTests {

    private func makeManager(columns: [TableColumn]) -> TableChangeManager {
        let table = DatabaseObject(kind: .table, name: "t", schema: nil)
        return TableChangeManager(table: table, schema: TableSchema(table: table, columns: columns))
    }

    private func textColumn(_ name: String, pk: Bool, position: Int) -> TableColumn {
        TableColumn(name: name, dataType: "text", isNullable: false, isPrimaryKey: pk, defaultValue: nil, position: position)
    }

    // MARK: - 复合主键分隔符碰撞

    /// 构造两行复合主键 (a,b)，使旧编码产生同一个 key：
    /// row1 a="x|b=y", b="z" 与 row2 a="x", b="y|b=z" 旧 key 均为 "a=x|b=y|b=z"。
    private func compositeManager() -> TableChangeManager {
        makeManager(columns: [
            textColumn("a", pk: true, position: 0),
            textColumn("b", pk: true, position: 1),
            textColumn("value", pk: false, position: 2),
        ])
    }

    private let compositeColumns = ["a", "b", "value"]
    private var compositeRow1: [DatabaseValue] { [.string("x|b=y"), .string("z"), .string("first")] }
    private var compositeRow2: [DatabaseValue] { [.string("x"), .string("y|b=z"), .string("second")] }

    @Test("复合主键含分隔符的两行编辑互不覆盖（回归 #555）")
    func compositePrimaryKeySeparatorCollisionKeepsBothEdits() {
        let manager = compositeManager()

        manager.stageCellUpdate(column: "value", newValue: .string("changed-first"), rowValues: compositeRow1, columns: compositeColumns)
        manager.stageCellUpdate(column: "value", newValue: .string("changed-second"), rowValues: compositeRow2, columns: compositeColumns)

        #expect(manager.changedCellCount == 2)
        let statements = manager.generatedUpdateStatements(for: .sqlite)
        #expect(statements.count == 2)
        // 两条 UPDATE 必须各自命中自己的主键，而不是都落到同一行。
        #expect(statements.contains { $0.contains("'x|b=y'") && $0.contains("'z'") && $0.contains("changed-first") })
        #expect(statements.contains { $0.contains("'x'") && $0.contains("'y|b=z'") && $0.contains("changed-second") })
    }

    @Test("复合主键含分隔符的两行删除都被保留（回归 #555）")
    func compositePrimaryKeyCollisionKeepsBothDeletions() {
        let manager = compositeManager()

        manager.toggleRowDeletion(rowValues: compositeRow1, columns: compositeColumns)
        manager.toggleRowDeletion(rowValues: compositeRow2, columns: compositeColumns)

        #expect(manager.pendingDeleteCount == 2)
        #expect(manager.isRowDeleted(rowValues: compositeRow1, columns: compositeColumns))
        #expect(manager.isRowDeleted(rowValues: compositeRow2, columns: compositeColumns))
        let statements = manager.generatedDeleteStatements(for: .sqlite)
        #expect(statements.count == 2)
        #expect(statements.contains { $0.contains("'x|b=y'") && $0.contains("'z'") })
        #expect(statements.contains { $0.contains("'x'") && $0.contains("'y|b=z'") })
    }

    // MARK: - 同长度 BLOB 主键

    @Test("同长度但内容不同的 BLOB 主键保持区分（回归 #555）")
    func sameLengthBlobPrimaryKeysStayDistinct() {
        let table = DatabaseObject(kind: .table, name: "t", schema: nil)
        let columns = [
            TableColumn(name: "id", dataType: "blob", isNullable: false, isPrimaryKey: true, defaultValue: nil, position: 0),
            textColumn("value", pk: false, position: 1),
        ]
        let manager = TableChangeManager(table: table, schema: TableSchema(table: table, columns: columns))
        let cols = ["id", "value"]
        let row1: [DatabaseValue] = [.data(Data([0x01, 0x02])), .string("first")]
        let row2: [DatabaseValue] = [.data(Data([0x03, 0x04])), .string("second")]

        manager.stageCellUpdate(column: "value", newValue: .string("changed-first"), rowValues: row1, columns: cols)
        manager.stageCellUpdate(column: "value", newValue: .string("changed-second"), rowValues: row2, columns: cols)

        // 旧编码两者都是 "id=2 bytes"，会相互覆盖。
        #expect(manager.changedCellCount == 2)
        #expect(manager.generatedUpdateStatements(for: .sqlite).count == 2)
    }

    // MARK: - issue 原始场景

    @Test("不同字符串主键各自生成独立的 UPDATE（回归 #555）")
    func distinctStringPrimaryKeysGenerateSeparateUpdates() {
        let manager = makeManager(columns: [
            textColumn("id", pk: true, position: 0),
            textColumn("value", pk: false, position: 1),
        ])
        let cols = ["id", "value"]
        let row1: [DatabaseValue] = [.string("a=b"), .string("first")]
        let row2: [DatabaseValue] = [.string("a"), .string("second")]

        manager.stageCellUpdate(column: "value", newValue: .string("changed-first"), rowValues: row1, columns: cols)
        manager.stageCellUpdate(column: "value", newValue: .string("changed-second"), rowValues: row2, columns: cols)

        #expect(manager.changedCellCount == 2)
        let statements = manager.generatedUpdateStatements(for: .sqlite)
        #expect(statements.count == 2)
        #expect(statements.contains { $0.contains("WHERE \"id\" = 'a=b'") && $0.contains("changed-first") })
        #expect(statements.contains { $0.contains("WHERE \"id\" = 'a'") && $0.contains("changed-second") })
    }

    @Test("rowKey 对含分隔符/同形异值的主键给出不同标识（回归 #555）")
    func rowKeyDistinguishesSeparatorLadenAndHomographValues() throws {
        let manager = makeManager(columns: [textColumn("id", pk: true, position: 0)])
        let cols = ["id"]
        func key(_ value: DatabaseValue) -> String? {
            manager.rowKey(rowValues: [value], columns: cols)
        }

        let a = try #require(key(.string("a=b")))
        let b = try #require(key(.string("a")))
        #expect(a != b)
        // 数字与同形字符串、含 | 的字符串都必须可区分。
        #expect(key(.integer(1)) != key(.string("1")))
        #expect(key(.string("x|y")) != key(.string("x")))
        #expect(key(.null) != key(.string("NULL")))
    }
}