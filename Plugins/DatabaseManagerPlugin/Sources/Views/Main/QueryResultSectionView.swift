import SwiftUI
import LumiUI
import LumiKernel

/// ``MainView`` 的查询/数据结果展示区。
///
/// 三态展示：
/// 1. `viewModel.errorMessage` 非空 → ``AppErrorBanner`` 错误条；
/// 2. `viewModel.queryResult` 非空 → ``QueryResultView`` 渲染表格；
/// 3. 否则 → ``AppEmptyState`` 占位（未选 SQLite 表时显示「请选择表格」，
///    选中表时显示「暂无结果」）。
///
/// 与父视图通过 `viewModel` 一个参数耦合，本视图本身不持有可变状态，
/// 因此可以安全地在多个父视图间复用（例如 SQLite 路径与 SQL 编辑器路径）。
struct QueryResultSectionView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    // MARK: - Properties

    @ObservedObject var viewModel: DatabaseViewModel

    // MARK: - Initialization

    init(viewModel: DatabaseViewModel) {
        self.viewModel = viewModel
    }

    // MARK: - Body

    @ViewBuilder
    var body: some View {
        if let error = viewModel.errorMessage {
            AppErrorBanner(message: LocalizedStringKey(error))
                .padding(12)
        } else if let result = viewModel.queryResult {
            // 仅在浏览表时启用表头排序点击 + 单元格编辑
            if viewModel.openTableObject != nil {
                QueryResultView(
                    result: result,
                    sortColumn: viewModel.tableOrderBy?.column,
                    sortAscending: viewModel.tableOrderBy?.ascending ?? true,
                    onToggleSort: { column in Task { await viewModel.toggleSort(column: column) } },
                    changeManager: viewModel.changeManager,
                    onStageChange: { column, rowValues, columns, newValue in
                        viewModel.stageCellChange(column: column, newValue: newValue, rowValues: rowValues, columns: columns)
                    },
                    onStageInsertChange: { insertId, column, value in
                        viewModel.stageInsertCell(insertId: insertId, column: column, value: value)
                    },
                    onToggleRowDeletion: { rowValues, columns in
                        viewModel.toggleRowDeletion(rowValues: rowValues, columns: columns)
                    },
                    onRemoveInsert: { insertId in
                        viewModel.removePendingInsert(insertId)
                    }
                )
            } else {
                QueryResultView(result: result)
            }
        } else {
            AppEmptyState(
                icon: viewModel.selectedSQLiteTable == nil ? "tablecells" : "tray",
                title: viewModel.selectedSQLiteTable == nil
                    ? LumiPluginLocalization.string("Select a table", bundle: .module)
                    : LumiPluginLocalization.string("No results", bundle: .module),
                description: viewModel.selectedSQLiteTable == nil
                    ? LumiPluginLocalization.string("Choose a table from the sidebar to view its data.", bundle: .module)
                    : nil
            )
        }
    }
}

// MARK: - 预览

#if DEBUG
#Preview("Results - Idle") {
    QueryResultSectionView(viewModel: DatabaseViewModel())
        .frame(width: 600, height: 300)
}
#endif
