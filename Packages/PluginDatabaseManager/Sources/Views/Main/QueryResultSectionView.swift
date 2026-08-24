import SwiftUI
import LumiUI

/// ``MainView`` 的查询/数据结果展示区。
///
/// 三态展示：
/// 1. `viewModel.errorMessage` 非空 → ``AppErrorBanner`` 错误条；
/// 2. `viewModel.queryResult` 非空 → ``QueryResultView`` 渲染表格；
/// 3. 否则 → ``AppEmptyState`` 占位。
///
/// 当存在多语句执行结果（``DatabaseViewModel/multiExecutions`` 非空）时，
/// 顶部额外显示一条 tab 栏，每条语句一个 tab（成功 ✓ / 失败 ✗ + 耗时），
/// 点击切换当前显示的结果；选中结果仍通过 `viewModel.queryResult` 下发给
/// ``QueryResultView``，保持向后兼容。
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
        if !viewModel.multiExecutions.isEmpty {
            VStack(spacing: 0) {
                multiExecutionTabs
                Divider()
                selectedResultContent
            }
        } else {
            singleResultContent
        }
    }

    // MARK: - Single result (no multi-exec)

    @ViewBuilder
    private var singleResultContent: some View {
        if let error = viewModel.errorMessage {
            AppErrorBanner(message: LocalizedStringKey(error))
                .padding(12)
        } else if let result = viewModel.queryResult {
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

    // MARK: - Multi-execution tab bar

    private var multiExecutionTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(Array(viewModel.multiExecutions.enumerated()), id: \.element.id) { index, exec in
                    tabButton(index: index, execution: exec)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .frame(height: 34)
        .background(Material.regularMaterial)
    }

    private func tabButton(index: Int, execution: StatementExecution) -> some View {
        let isSelected = viewModel.selectedExecutionIndex == index
        let title = tabTitle(index: index, sql: execution.sql)
        return Button {
            viewModel.selectedExecutionIndex = index
            viewModel.queryResult = execution.result
        } label: {
            HStack(spacing: 4) {
                Image(systemName: execution.succeeded ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(execution.succeeded ? theme.success : theme.error)
                Text(title)
                    .font(.appMicro)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(theme.textPrimary)
                Text(String(format: "%.0f ms", execution.durationMs))
                    .font(.appMicro)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isSelected ? theme.primary.opacity(0.15) : Color.clear)
            .clipShape(.rect(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    private func tabTitle(index: Int, sql: String) -> String {
        let firstLine = sql.split(separator: "\n").first.map(String.init) ?? sql
        let trimmed = firstLine.trimmingCharacters(in: .whitespaces)
        let preview: String
        if trimmed.count > 28 {
            preview = String(trimmed.prefix(28)) + "…"
        } else {
            preview = trimmed
        }
        return "#\(index + 1) \(preview)"
    }

    // MARK: - Selected result (in multi-exec)

    @ViewBuilder
    private var selectedResultContent: some View {
        let idx = viewModel.selectedExecutionIndex
        if idx >= 0, idx < viewModel.multiExecutions.count {
            let exec = viewModel.multiExecutions[idx]
            if let err = exec.errorMessage {
                AppErrorBanner(message: LocalizedStringKey(err))
                    .padding(12)
            } else if let result = exec.result {
                QueryResultView(result: result)
            } else {
                AppEmptyState(icon: "tray", title: LumiPluginLocalization.string("No results", bundle: .module))
            }
        } else {
            AppEmptyState(icon: "tray", title: LumiPluginLocalization.string("No results", bundle: .module))
        }
    }
}

// MARK: - 预览

#if DEBUG
#Preview("Results - Idle") {
    QueryResultSectionView(viewModel: DatabaseViewModel(loadSavedConfigs: false))
        .frame(width: 600, height: 300)
}
#endif
