import SwiftUI
import LumiUI
import LumiKernel

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

    // MARK: - Constants

    /// 列宽：header 与 row 共享同一宽度，让两列对齐。
    private static let columnWidth: CGFloat = 160

    // MARK: - Body

    var body: some View {
        GeometryReader { proxy in
            ScrollView([.horizontal, .vertical]) {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    Section {
                        ForEach(0 ..< result.rows.count, id: \.self) { rowIndex in
                            let row = result.rows[rowIndex]
                            resultRow(row: row)
                        }
                    } header: {
                        headerRow
                    }

                    Spacer()
                }
                // 内容比视口小时：撑满视口并靠左上对齐（Spacer 把行顶到顶部、单元格推到左侧）。
                // 内容比视口大时：min 约束不生效，自然产生横/纵滚动。
                // 不能用 maxWidth/maxHeight: .infinity —— 双向 ScrollView 在两个方向都给无界 proposal，
                // 内容会塌缩成理想尺寸并被 ScrollView 居中（即之前「跑到中间」的原因）。
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

    /// 表格总宽度：列数 × 列宽。撑出 ScrollView 的最小可滚动宽度，
    /// 这样列多时能横向滚动、列少时不会因为 frame 居中而错位。
    private var tableWidth: CGFloat {
        CGFloat(result.columns.count) * Self.columnWidth
    }

    // MARK: - Subviews

    private var headerRow: some View {
        HStack(spacing: 0) {
            ForEach(result.columns, id: \.self) { col in
                Text(col)
                    .font(.appBodyEmphasized)
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(8)
                    .frame(width: Self.columnWidth, alignment: .leading)
                    .border(theme.appSubtleBorder)
            }
            Spacer(minLength: 0)
        }
        .background(Material.regularMaterial)
    }

    private func resultRow(row: [DatabaseValue]) -> some View {
        HStack(spacing: 0) {
            ForEach(0 ..< row.count, id: \.self) { colIndex in
                let text = content(for: row[colIndex])
                Text(text)
                    .font(.monospaced(.body)())
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(8)
                    .frame(width: Self.columnWidth, alignment: .leading)
                    .border(theme.appSubtleBorder.opacity(0.7))
                    .contextMenu {
                        Button(LumiPluginLocalization.string("Copy", bundle: .module)) {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(text, forType: .string)
                        }
                    }
            }
            Spacer(minLength: 0)
        }
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
