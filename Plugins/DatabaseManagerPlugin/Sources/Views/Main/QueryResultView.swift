import SwiftUI
import LumiUI

/// 查询结果的表格渲染视图。
///
/// 由 ``QueryResultSectionView`` 在 `viewModel.queryResult` 非空时调用，
/// 渲染一个 ScrollView 包住 LazyVStack 的表格视图：
/// - 列头通过 `pinnedViews: [.sectionHeaders]` 在纵向滚动时钉在视口顶部；
/// - 每列固定宽度 `columnWidth`，列多时可横向滚动；
/// - 单元格支持右键复制内容到剪贴板。
struct QueryResultView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    // MARK: - Properties

    let result: QueryResult
    /// 当前排序列（nil 表示未排序）。
    var sortColumn: String? = nil
    /// 排序方向（仅在 sortColumn 非空时有意义）。
    var sortAscending: Bool = true
    /// 表头点击回调；nil 时表头不可点击。
    var onToggleSort: ((String) -> Void)? = nil
    /// 变更跟踪器；非空且可编辑时单元格支持双击编辑与高亮。
    var changeManager: TableChangeManager? = nil
    /// 单元格提交回调：(列名, 当前行, 全部列名, 新值)。
    var onStageChange: ((String, [DatabaseValue], [String], DatabaseValue) -> Void)? = nil
    /// 新增行列提交回调：(insertId, 列名, 新值)。
    var onStageInsertChange: ((UUID, String, DatabaseValue) -> Void)? = nil
    /// 切换行删除回调：(行值, 列名)。
    var onToggleRowDeletion: (([DatabaseValue], [String]) -> Void)? = nil
    /// 移除未保存新增行回调。
    var onRemoveInsert: ((UUID) -> Void)? = nil

    // MARK: - Editing state

    private struct CellKey: Hashable { let row: Int; let col: Int }
    private struct InsertCellKey: Hashable { let insertId: UUID; let column: String }
    @State private var editingCell: CellKey? = nil
    @State private var editText: String = ""
    @State private var editingInsert: InsertCellKey? = nil
    @State private var editInsertText: String = ""
    @FocusState private var editorFocused: Bool

    // MARK: - Constants

    /// 行号列宽度。
    private static let rowNumberWidth: CGFloat = 44
    /// 列宽上下限，避免过窄或过宽。
    private static let minColumnWidth: CGFloat = 80
    private static let maxColumnWidth: CGFloat = 320
    /// 每字符近似宽度（等宽字体 body），用于按内容估算列宽。
    private static let approxCharWidth: CGFloat = 8

    // MARK: - Body

    var body: some View {
        GeometryReader { proxy in
            ScrollView([.horizontal, .vertical]) {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    Section {
                        ForEach(0 ..< result.rows.count, id: \.self) { rowIndex in
                            resultRow(at: rowIndex)
                        }
                        if let cm = changeManager, !cm.pendingInserts.isEmpty {
                            ForEach(cm.pendingInserts) { insert in
                                insertedRow(insert)
                            }
                        }
                    } header: {
                        headerRow
                    }

                    Spacer()
                }
                // 内容比视口小时：撑满视口并靠左上对齐；比视口大时：自然产生横/纵滚动。
                .frame(
                    minWidth: max(proxy.size.width, tableWidth),
                    minHeight: proxy.size.height,
                    alignment: .topLeading
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Layout

    /// 行号列 + 各数据列宽度之和。
    private var tableWidth: CGFloat {
        Self.rowNumberWidth + columnWidths.reduce(0, +)
    }

    /// 按列名 + 前 50 行内容估算的列宽（钳制在上下限内）。
    private var columnWidths: [CGFloat] {
        let sampleCount = min(50, result.rows.count)
        return result.columns.indices.map { colIndex in
            var maxChars = result.columns[colIndex].count
            for r in 0..<sampleCount {
                guard colIndex < result.rows[r].count else { continue }
                let text = content(for: result.rows[r][colIndex])
                maxChars = max(maxChars, text.count)
            }
            let width = CGFloat(maxChars) * Self.approxCharWidth + 24  // padding 余量
            return min(max(width, Self.minColumnWidth), Self.maxColumnWidth)
        }
    }

    // MARK: - Subviews

    private var headerRow: some View {
        HStack(spacing: 0) {
            Text("#")
                .font(.appMicroEmphasized)
                .foregroundStyle(.secondary)
                .frame(width: Self.rowNumberWidth, alignment: .center)
                .border(theme.appSubtleBorder)
            ForEach(result.columns.indices, id: \.self) { colIndex in
                headerCell(for: colIndex)
            }
            Spacer(minLength: 0)
        }
        .background(Material.regularMaterial)
    }

    @ViewBuilder
    private func headerCell(for colIndex: Int) -> some View {
        let name = result.columns[colIndex]
        let isSorted = (sortColumn == name)
        let label = HStack(spacing: 4) {
            Text(name)
                .lineLimit(1)
                .truncationMode(.tail)
            if isSorted {
                Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
            }
            Spacer(minLength: 0)
        }
        .font(.appBodyEmphasized)
        .foregroundColor(theme.textPrimary)
        .padding(8)
        .frame(width: columnWidths[colIndex], alignment: .leading)
        .border(theme.appSubtleBorder)

        if let onToggleSort {
            Button(action: { onToggleSort(name) }) {
                label
            }
            .buttonStyle(.plain)
        } else {
            label
        }
    }

    private func resultRow(at rowIndex: Int) -> some View {
        let row = result.rows[rowIndex]
        let isDeleted = changeManager?.isRowDeleted(rowValues: row, columns: result.columns) ?? false
        return HStack(spacing: 0) {
            Text("\(rowIndex + 1)")
                .font(.appMicro)
                .foregroundStyle(isDeleted ? theme.error : .secondary)
                .frame(width: Self.rowNumberWidth, alignment: .center)
                .background(isDeleted ? theme.error.opacity(0.1) : Color.secondary.opacity(0.04))
                .border(theme.appSubtleBorder.opacity(0.7))

            ForEach(0 ..< row.count, id: \.self) { colIndex in
                cellView(row: row, rowIndex: rowIndex, colIndex: colIndex, width: columnWidths[colIndex])
                    .strikethrough(isDeleted)
                    .opacity(isDeleted ? 0.55 : 1)
            }
            Spacer(minLength: 0)
        }
        .contextMenu {
            if changeManager?.isEditable == true {
                if isDeleted {
                    Button(LumiPluginLocalization.string("Undelete Row", bundle: .module)) {
                        onToggleRowDeletion?(row, result.columns)
                    }
                } else {
                    Button(role: .destructive) {
                        onToggleRowDeletion?(row, result.columns)
                    } label: {
                        Label(LumiPluginLocalization.string("Delete Row", bundle: .module), systemImage: "trash")
                    }
                }
            }
        }
    }

    /// 渲染一条未保存的新增行（行号显示 "+"）。
    private func insertedRow(_ insert: TableChangeManager.PendingInsert) -> some View {
        return HStack(spacing: 0) {
            Text("+")
                .font(.appMicroEmphasized)
                .foregroundStyle(theme.success)
                .frame(width: Self.rowNumberWidth, alignment: .center)
                .background(theme.success.opacity(0.08))
                .border(theme.appSubtleBorder.opacity(0.7))

            ForEach(result.columns.indices, id: \.self) { colIndex in
                insertCellView(insert: insert, column: result.columns[colIndex], width: columnWidths[colIndex])
            }
            Spacer(minLength: 0)
        }
        .contextMenu {
            Button(role: .destructive) {
                onRemoveInsert?(insert.id)
            } label: {
                Label(LumiPluginLocalization.string("Remove Row", bundle: .module), systemImage: "minus.circle")
            }
        }
    }

    @ViewBuilder
    private func insertCellView(insert: TableChangeManager.PendingInsert, column: String, width: CGFloat) -> some View {
        let key = InsertCellKey(insertId: insert.id, column: column)
        if editingInsert == key {
            TextField("", text: $editInsertText)
                .font(.monospaced(.body)())
                .textFieldStyle(.plain)
                .padding(8)
                .frame(width: width, alignment: .leading)
                .background(theme.success.opacity(0.15))
                .border(theme.success)
                .focused($editorFocused)
                .onSubmit { commitInsertEdit(insertId: insert.id, column: column) }
                .onAppear { editorFocused = true }
                .onKeyPress(.escape) { editingInsert = nil; return .handled }
        } else {
            let value = changeManager?.insertDisplayValue(insertId: insert.id, column: column) ?? .null
            let text = content(for: value)
            Text(text)
                .font(.monospaced(.body)())
                .foregroundColor(value == .null ? theme.textTertiary : theme.textPrimary)
                .italic(value == .null)
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(8)
                .frame(width: width, alignment: .leading)
                .background(theme.success.opacity(0.06))
                .border(theme.appSubtleBorder.opacity(0.7))
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    editInsertText = (value == .null ? "" : text)
                    editingInsert = key
                }
                .contextMenu {
                    Button(LumiPluginLocalization.string("Set NULL", bundle: .module)) {
                        onStageInsertChange?(insert.id, column, .null)
                    }
                }
        }
    }

    private func commitInsertEdit(insertId: UUID, column: String) {
        let value = parseEditedCellValue(editInsertText)
        onStageInsertChange?(insertId, column, value)
        editingInsert = nil
    }

    @ViewBuilder
    private func cellView(row: [DatabaseValue], rowIndex: Int, colIndex: Int, width: CGFloat) -> some View {
        let column = result.columns[colIndex]
        let displayed = displayedValue(row: row, column: column)
        let isChanged = changeManager?.isCellChanged(column: column, rowValues: row, columns: result.columns) ?? false
        let isNull = displayed == .null
        let key = CellKey(row: rowIndex, col: colIndex)

        if editingCell == key {
            TextField("", text: $editText)
                .font(.monospaced(.body)())
                .textFieldStyle(.plain)
                .padding(8)
                .frame(width: width, alignment: .leading)
                .background(theme.warning.opacity(0.15))
                .border(theme.warning)
                .focused($editorFocused)
                .onSubmit { commitEdit(row: row, column: column) }
                .onAppear { editorFocused = true }
                .onKeyPress(.escape) {
                    editingCell = nil
                    return .handled
                }
        } else {
            let text = content(for: displayed)
            Text(text)
                .font(.monospaced(.body)())
                .foregroundColor(isNull ? theme.textTertiary : theme.textPrimary)
                .italic(isNull)
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(8)
                .frame(width: width, alignment: .leading)
                .background(isChanged ? theme.warning.opacity(0.18) : Color.clear)
                .border(theme.appSubtleBorder.opacity(0.7))
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    guard changeManager?.isEditable == true else { return }
                    editText = (isNull ? "" : text)
                    editingCell = key
                }
                .contextMenu {
                    Button(LumiPluginLocalization.string("Copy", bundle: .module)) {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(text, forType: .string)
                    }
                    if changeManager?.isEditable == true {
                        Button(LumiPluginLocalization.string("Set NULL", bundle: .module)) {
                            onStageChange?(column, row, result.columns, .null)
                        }
                    }
                }
        }
    }

    /// 显示值：优先取变更队列里的暂存值，否则取结果原始值。
    private func displayedValue(row: [DatabaseValue], column: String) -> DatabaseValue {
        if let cm = changeManager {
            return cm.displayedValue(column: column, rowValues: row, columns: result.columns)
        }
        guard let idx = result.columns.firstIndex(of: column), idx < row.count else { return .null }
        return row[idx]
    }

    private func commitEdit(row: [DatabaseValue], column: String) {
        let value = parseEditedCellValue(editText)
        onStageChange?(column, row, result.columns, value)
        editingCell = nil
    }

    // MARK: - Helpers

    private func content(for value: DatabaseValue) -> String {
        switch value {
        case let .integer(v): return String(v)
        case let .double(v): return String(v)
        case let .string(v): return v
        case let .bool(v): return String(v)
        case let .data(v): return "<BLOB \(v.count) bytes>"
        case .null: return "NULL"
        }
    }
}

// MARK: - 预览

#if DEBUG
#Preview("Empty Table") {
    QueryResultView(
        result: QueryResult(
            columns: ["id", "name", "created_at"],
            rows: [
                [DatabaseValue.integer(1), DatabaseValue.string("Alice"), DatabaseValue.string("2024-01-01")],
                [DatabaseValue.integer(2), DatabaseValue.string("Bob"), DatabaseValue.null]
            ],
            rowsAffected: 0
        )
    )
    .frame(width: 560, height: 240)
}
#endif
