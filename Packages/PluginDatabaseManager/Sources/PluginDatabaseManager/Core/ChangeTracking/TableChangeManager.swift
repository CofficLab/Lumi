import Foundation
import Combine

/// 把一个 ``DatabaseValue`` 转成 SQL 字面量（内联、已转义）。
///
/// 采用内联而非参数绑定，是为了在 SQLite/MySQL/PostgreSQL 三种方言下统一生成
/// 可直接 `execute(sql, params: nil)` 的语句。BLOB 暂不支持内联（v1 视为只读）。
public func sqlLiteral(for value: DatabaseValue, dialect: DatabaseType) -> String {
    switch value {
    case .null:
        return "NULL"
    case .integer(let i):
        return String(i)
    case .double(let d):
        return String(d)
    case .bool(let b):
        return b ? "TRUE" : "FALSE"
    case .string(let s):
        return "'" + escapeSQLString(s, dialect: dialect) + "'"
    case .data:
        // BLOB 编辑在 v1 不支持；生成 NULL 避免破坏语句结构。
        return "NULL"
    }
}

/// MySQL 默认开启反斜杠转义（NO_BACKSLASH_ESCAPES 关闭），`\n`/`\t`/`\0` 会被
/// 解释成控制字符，必须先转义反斜杠再转义单引号，否则保存会静默改写用户输入（#582）。
/// SQLite/PostgreSQL 标准字符串里反斜杠是普通字符，只转义单引号。
private func escapeSQLString(_ s: String, dialect: DatabaseType) -> String {
    var escaped = s
    if dialect == .mysql {
        escaped = escaped.replacingOccurrences(of: "\\", with: "\\\\")
    }
    return escaped.replacingOccurrences(of: "'", with: "''")
}

/// 判断列声明类型是否为文本类。文本列的编辑必须保留用户输入的原始字符串，
/// 不得 trim、把空串/「NULL」映射成 SQL NULL，也不做数字/布尔推断（#554）。
/// 覆盖三方言常见文本类型：CHAR/VARCHAR/NCHAR/NVARCHAR/CHARACTER VARYING、
/// TEXT/TINYTEXT/MEDIUMTEXT/LONGTEXT、CLOB/NCLOB、SQLite STRING 亲和、
/// JSON/JSONB、UUID、XML、MySQL ENUM/SET。未知或数值/布尔类型返回 false，
/// 沿用既有推断行为。
func isTextColumnType(_ dataType: String?) -> Bool {
    guard let dataType, !dataType.isEmpty else { return false }
    let upper = dataType.uppercased()
    let textMarkers = ["CHAR", "TEXT", "CLOB", "STRING", "JSON", "UUID", "XML", "ENUM", "SET"]
    return textMarkers.contains { upper.contains($0) }
}

/// 把单元格编辑文本解析为 ``DatabaseValue``。
///
/// 传入 `columnType` 且为文本类列时，原样保留输入字符串（含首尾空白、空串、
/// `NULL`、形似数字的文本）；NULL 由独立的「Set NULL」菜单提供，不占用合法
/// 字符串值（#554）。其余列（数值/布尔/未知）沿用：空 / `NULL` → null；
/// 整数 → integer；小数 → double；true/false → bool；其余 → string。
public func parseEditedCellValue(_ text: String, columnType: String? = nil) -> DatabaseValue {
    if isTextColumnType(columnType) {
        return .string(text)
    }
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty || trimmed.uppercased() == "NULL" { return .null }
    if let i = Int(trimmed) { return .integer(i) }
    if let d = Double(trimmed) { return .double(d) }
    switch trimmed.lowercased() {
    case "true": return .bool(true)
    case "false": return .bool(false)
    default: return .string(trimmed)
    }
}

/// 表数据编辑的"变更跟踪队列"：在内存中暂存单元格修改、行新增、行删除，不立即写库。
///
/// 设计参考 TablePro 的 Change Tracking：
/// - 编辑只改内存，单元格/行高亮提示；
/// - 保存时按 DELETE → INSERT → UPDATE 顺序在事务中执行；
/// - 行以**主键值**定位（无主键的表暂不支持编辑）；
/// - 撤销/重做用**快照式**栈：每次变更前快照状态，undo/redo 交换当前与快照。
@MainActor
public final class TableChangeManager: ObservableObject {
    /// 单行的待提交更新。
    public struct PendingRowUpdate {
        public let primaryKeyValues: [(column: String, value: DatabaseValue)]
        public var columnUpdates: [String: DatabaseValue]
    }

    /// 一条待新增的行（暂存各列值，未设的列在保存时使用数据库默认值）。
    public struct PendingInsert: Identifiable {
        public let id: UUID
        public var columnValues: [String: DatabaseValue]
    }

    /// 变更全量快照（供 undo/redo）。
    private struct Snapshot {
        let updatesByRow: [String: PendingRowUpdate]
        let pendingInserts: [PendingInsert]
        let deletedRowKeys: Set<String>
        let deletedPKValues: [String: [(column: String, value: DatabaseValue)]]
    }

    @Published public private(set) var updatesByRow: [String: PendingRowUpdate] = [:]
    @Published public private(set) var pendingInserts: [PendingInsert] = []
    @Published public private(set) var deletedRowKeys: Set<String> = []
    private var deletedPKValues: [String: [(column: String, value: DatabaseValue)]] = [:]

    private var undoStack: [Snapshot] = []
    private var redoStack: [Snapshot] = []

    public let table: DatabaseObject
    public let schema: TableSchema
    private let pkColumns: [String]
    private let allColumnNames: [String]

    public init(table: DatabaseObject, schema: TableSchema) {
        self.table = table
        self.schema = schema
        self.pkColumns = schema.columns.filter(\.isPrimaryKey).map(\.name)
        self.allColumnNames = schema.columns.map(\.name)
    }

    public var isEditable: Bool { !pkColumns.isEmpty }
    public var primaryKeyColumnNames: [String] { pkColumns }

    public var hasChanges: Bool {
        !updatesByRow.isEmpty || !pendingInserts.isEmpty || !deletedRowKeys.isEmpty
    }

    /// 已修改的单元格总数（仅 UPDATE）。
    public var changedCellCount: Int {
        updatesByRow.values.reduce(0) { $0 + $1.columnUpdates.count }
    }

    public var pendingInsertCount: Int { pendingInserts.count }
    public var pendingDeleteCount: Int { deletedRowKeys.count }

    /// 全部待提交变更条目数（用于变更条汇总显示）。
    public var totalPendingCount: Int {
        changedCellCount + pendingInsertCount + pendingDeleteCount
    }

    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }

    // MARK: - Row identity

    public func rowKey(rowValues: [DatabaseValue], columns: [String]) -> String? {
        guard !pkColumns.isEmpty else { return nil }
        return pkColumns.map { pk -> String in
            let value = value(of: pk, in: rowValues, columns: columns)
            return Self.rowKeyComponent(column: pk, value: value)
        }.joined(separator: "|")
    }

    /// 主键行标识的规范编码：列名与值都带 UTF-8 字节长度前缀，值再带类型标签。
    ///
    /// 直接用 `"\(pk)=\(value.description)"` 以 `|` 拼接会让不同主键碰撞
    /// （如 `id='a=b'` 与 `id='a'`、含 `|` 的字符串、同长度 BLOB、数字与同形字符串），
    /// 使两行的编辑/删除状态相互覆盖，最终 UPDATE/DELETE 作用到错误的主键（#555）。
    /// 长度前缀 + 类型标签保证编码唯一且可逆。
    private static func rowKeyComponent(column: String, value: DatabaseValue) -> String {
        let tag: String
        let payload: String
        switch value {
        case .null: tag = "n"; payload = ""
        case .integer(let i): tag = "i"; payload = String(i)
        case .double(let d): tag = "d"; payload = String(d)
        case .bool(let b): tag = "b"; payload = b ? "1" : "0"
        case .string(let s): tag = "s"; payload = s
        case .data(let data): tag = "x"; payload = data.base64EncodedString()
        }
        return "\(column.utf8.count):\(column)=\(tag)\(payload.utf8.count):\(payload)"
    }

    public func isRowDeleted(rowValues: [DatabaseValue], columns: [String]) -> Bool {
        guard let key = rowKey(rowValues: rowValues, columns: columns) else { return false }
        return deletedRowKeys.contains(key)
    }

    public func displayedValue(column: String, rowValues: [DatabaseValue], columns: [String]) -> DatabaseValue {
        if let key = rowKey(rowValues: rowValues, columns: columns),
           let update = updatesByRow[key],
           let staged = update.columnUpdates[column] {
            return staged
        }
        return value(of: column, in: rowValues, columns: columns)
    }

    public func isCellChanged(column: String, rowValues: [DatabaseValue], columns: [String]) -> Bool {
        guard let key = rowKey(rowValues: rowValues, columns: columns) else { return false }
        return updatesByRow[key]?.columnUpdates[column] != nil
    }

    // MARK: - Cell updates

    /// 按列声明类型解析编辑文本：文本列保留原始字符串，数值/布尔列沿用推断（#554）。
    /// 编辑提交入口（QueryResultView）调用它，而不是无类型的 `parseEditedCellValue`。
    public func parseEditedValue(_ text: String, column: String) -> DatabaseValue {
        let dataType = schema.columns.first(where: { $0.name == column })?.dataType
        return parseEditedCellValue(text, columnType: dataType)
    }

    public func stageCellUpdate(
        column: String,
        newValue: DatabaseValue,
        rowValues: [DatabaseValue],
        columns: [String]
    ) {
        guard let key = rowKey(rowValues: rowValues, columns: columns) else { return }
        // 已删除的行不允许再改单元格
        guard !deletedRowKeys.contains(key) else { return }
        let original = value(of: column, in: rowValues, columns: columns)
        // BLOB 在 v1 只读：拒绝暂存，避免把占位文本当成字符串覆盖原始二进制（#281）。
        if case .data = original { return }
        recordUndo()

        if newValue == original {
            if var row = updatesByRow[key] {
                row.columnUpdates.removeValue(forKey: column)
                if row.columnUpdates.isEmpty {
                    updatesByRow.removeValue(forKey: key)
                } else {
                    updatesByRow[key] = row
                }
            }
            return
        }

        if var existing = updatesByRow[key] {
            existing.columnUpdates[column] = newValue
            updatesByRow[key] = existing
        } else {
            let pkValues = pkColumns.map { (column: $0, value: value(of: $0, in: rowValues, columns: columns)) }
            updatesByRow[key] = PendingRowUpdate(primaryKeyValues: pkValues, columnUpdates: [column: newValue])
        }
    }

    // MARK: - Inserts

    /// 新增一行（空），返回临时 id。用户随后编辑其各列。
    @discardableResult
    public func addInsert() -> UUID {
        recordUndo()
        let insert = PendingInsert(id: UUID(), columnValues: [:])
        pendingInserts.append(insert)
        return insert.id
    }

    public func setInsertColumn(insertId: UUID, column: String, value: DatabaseValue) {
        guard let index = pendingInserts.firstIndex(where: { $0.id == insertId }) else { return }
        recordUndo()
        pendingInserts[index].columnValues[column] = value
    }

    public func insertDisplayValue(insertId: UUID, column: String) -> DatabaseValue {
        pendingInserts.first(where: { $0.id == insertId })?.columnValues[column] ?? .null
    }

    public func removeInsert(_ insertId: UUID) {
        recordUndo()
        pendingInserts.removeAll { $0.id == insertId }
    }

    // MARK: - Deletes

    /// 切换某行的删除标记。
    public func toggleRowDeletion(rowValues: [DatabaseValue], columns: [String]) {
        guard let key = rowKey(rowValues: rowValues, columns: columns) else { return }
        recordUndo()
        if deletedRowKeys.contains(key) {
            deletedRowKeys.remove(key)
            deletedPKValues.removeValue(forKey: key)
        } else {
            deletedRowKeys.insert(key)
            deletedPKValues[key] = pkColumns.map { (column: $0, value: value(of: $0, in: rowValues, columns: columns)) }
            // 删除后该行的单元格更新不再有意义，移除
            updatesByRow.removeValue(forKey: key)
        }
    }

    // MARK: - Undo / Redo

    public func undo() {
        guard let snapshot = undoStack.popLast() else { return }
        redoStack.append(currentSnapshot())
        restore(snapshot)
    }

    public func redo() {
        guard let snapshot = redoStack.popLast() else { return }
        undoStack.append(currentSnapshot())
        restore(snapshot)
    }

    public func discardAll() {
        recordUndo()
        updatesByRow.removeAll()
        pendingInserts.removeAll()
        deletedRowKeys.removeAll()
        deletedPKValues.removeAll()
    }

    // MARK: - SQL generation

    /// DELETE → INSERT → UPDATE（顺序便于"删旧行 + 插同主键新行"场景）。
    public func generatedAllStatements(for type: DatabaseType) -> [String] {
        generatedDeleteStatements(for: type) + generatedInsertStatements(for: type) + generatedUpdateStatements(for: type)
    }

    public func generatedUpdateStatements(for type: DatabaseType) -> [String] {
        let tableExpr = DatabaseViewModel.qualifiedName(for: table, type: type)
        func q(_ name: String) -> String { DatabaseViewModel.quoteIdentifier(name, for: type) }

        return updatesByRow.values.map { row in
            let setClause = row.columnUpdates.map { "\(q($0.key)) = \(sqlLiteral(for: $0.value, dialect: type))" }
                .joined(separator: ", ")
            let whereClause = row.primaryKeyValues
                .map { "\(q($0.column)) = \(sqlLiteral(for: $0.value, dialect: type))" }
                .joined(separator: " AND ")
            return "UPDATE \(tableExpr) SET \(setClause) WHERE \(whereClause);"
        }
    }

    public func generatedInsertStatements(for type: DatabaseType) -> [String] {
        let tableExpr = DatabaseViewModel.qualifiedName(for: table, type: type)
        func q(_ name: String) -> String { DatabaseViewModel.quoteIdentifier(name, for: type) }

        return pendingInserts.map { insert in
            if insert.columnValues.isEmpty {
                // 空行：让数据库填充默认值。
                // SQLite 与 PostgreSQL 都接受 DEFAULT VALUES；MySQL 不支持该语法，
                // 须用空列清单 () VALUES ()，否则 PostgreSQL 会语法报错并回滚保存（#280）。
                switch type {
                case .sqlite, .postgresql:
                    return "INSERT INTO \(tableExpr) DEFAULT VALUES;"
                case .mysql:
                    return "INSERT INTO \(tableExpr) () VALUES ();"
                case .redis:
                    return ""
                }
            }
            // 按表结构列顺序输出，保证可读性
            let orderedColumns = allColumnNames.filter { insert.columnValues[$0] != nil }
            let cols = orderedColumns.map(q).joined(separator: ", ")
            let vals = orderedColumns.map { sqlLiteral(for: insert.columnValues[$0]!, dialect: type) }.joined(separator: ", ")
            return "INSERT INTO \(tableExpr) (\(cols)) VALUES (\(vals));"
        }
        .filter { !$0.isEmpty }
    }

    public func generatedDeleteStatements(for type: DatabaseType) -> [String] {
        let tableExpr = DatabaseViewModel.qualifiedName(for: table, type: type)
        func q(_ name: String) -> String { DatabaseViewModel.quoteIdentifier(name, for: type) }

        return deletedRowKeys.compactMap { key -> String? in
            guard let pkValues = deletedPKValues[key] else { return nil }
            let whereClause = pkValues
                .map { "\(q($0.column)) = \(sqlLiteral(for: $0.value, dialect: type))" }
                .joined(separator: " AND ")
            return "DELETE FROM \(tableExpr) WHERE \(whereClause);"
        }
    }

    // MARK: - Snapshot helpers

    private func currentSnapshot() -> Snapshot {
        Snapshot(updatesByRow: updatesByRow, pendingInserts: pendingInserts, deletedRowKeys: deletedRowKeys, deletedPKValues: deletedPKValues)
    }

    private func restore(_ snapshot: Snapshot) {
        updatesByRow = snapshot.updatesByRow
        pendingInserts = snapshot.pendingInserts
        deletedRowKeys = snapshot.deletedRowKeys
        deletedPKValues = snapshot.deletedPKValues
    }

    private func recordUndo() {
        undoStack.append(currentSnapshot())
        redoStack.removeAll()
    }

    // MARK: - Value lookup

    private func value(of column: String, in rowValues: [DatabaseValue], columns: [String]) -> DatabaseValue {
        guard let index = columns.firstIndex(of: column), index < rowValues.count else { return .null }
        return rowValues[index]
    }
}
