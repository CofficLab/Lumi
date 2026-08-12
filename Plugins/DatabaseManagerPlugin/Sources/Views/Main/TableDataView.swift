import LumiKernel
import LumiUI
import SwiftUI

/// 统一的表数据浏览视图：顶部标题栏 + 分页条 + 结果区。
///
/// 当 ``DatabaseViewModel/openTableObject`` 非空时由 ``MainView`` 显示，
/// 适用于 SQLite/MySQL/PostgreSQL（Redis 走键浏览路径）。
/// 分页通过 `LIMIT/OFFSET`，行数通过后台 `COUNT(*)` 异步填充。
struct TableDataView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme
    @ObservedObject var viewModel: DatabaseViewModel

    private let pageSizes: [Int] = [50, 100, 200, 500, 1000]

    var body: some View {
        VStack(spacing: 0) {
            header
            AppDivider()
            QueryResultSectionView(viewModel: viewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            if viewModel.changeManager?.hasChanges == true {
                changesBar
                AppDivider()
            }
            paginationBar
        }
        .sheet(isPresented: $viewModel.showChangePreview) {
            ChangePreviewSheet(
                statements: viewModel.pendingChangeSQL,
                isPresented: $viewModel.showChangePreview,
                onSave: { Task { await viewModel.saveChanges() } }
            )
        }
    }

    // MARK: - Changes bar

    private var changesBar: some View {
        let cm = viewModel.changeManager
        return HStack(spacing: 8) {
            Image(systemName: "pencil.line")
                .foregroundStyle(theme.warning)
            Text(changeSummary(cm))
                .font(.appMicroEmphasized)
                .foregroundStyle(theme.textPrimary)

            AppIconButton(systemImage: "arrow.uturn.backward", label: "Undo", size: .compact) {
                viewModel.undoChange()
            }
            .disabled(cm?.canUndo != true)

            AppIconButton(systemImage: "arrow.uturn.forward", label: "Redo", size: .compact) {
                viewModel.redoChange()
            }
            .disabled(cm?.canRedo != true)

            Spacer()
            AppButton(LumiPluginLocalization.string("Preview SQL", bundle: .module), systemImage: "doc.text.magnifyingglass", style: .ghost, size: .small) {
                viewModel.showChangePreview = true
            }
            AppButton(LumiPluginLocalization.string("Discard", bundle: .module), systemImage: "trash", style: .secondary, size: .small) {
                viewModel.discardChanges()
            }
            AppButton(LumiPluginLocalization.string("Save", bundle: .module), systemImage: "checkmark.circle.fill", style: .primary, size: .small) {
                Task { await viewModel.saveChanges() }
            }
            .keyboardShortcut("s", modifiers: .command)
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(theme.warning.opacity(0.08))
    }

    /// 变更条摘要：按类型列出 edit/insert/delete 计数。
    private func changeSummary(_ cm: TableChangeManager?) -> String {
        guard let cm else { return "" }
        var parts: [String] = []
        if cm.changedCellCount > 0 {
            parts.append("\(cm.changedCellCount) \(LumiPluginLocalization.string("edits", bundle: .module))")
        }
        if cm.pendingInsertCount > 0 {
            parts.append("\(cm.pendingInsertCount) \(LumiPluginLocalization.string("new", bundle: .module))")
        }
        if cm.pendingDeleteCount > 0 {
            parts.append("\(cm.pendingDeleteCount) \(LumiPluginLocalization.string("deletes", bundle: .module))")
        }
        return parts.isEmpty
            ? LumiPluginLocalization.string("No changes", bundle: .module)
            : parts.joined(separator: " · ") + " " + LumiPluginLocalization.string("unsaved", bundle: .module)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.appBodyEmphasized)
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if let count = viewModel.tableRowCount {
                    Text("\(count.formatted()) \(LumiPluginLocalization.string("rows", bundle: .module))")
                        .font(.appCaption)
                        .foregroundColor(theme.textSecondary)
                } else if viewModel.isLoading {
                    Text(LumiPluginLocalization.string("Loading…", bundle: .module))
                        .font(.appCaption)
                        .foregroundColor(theme.textSecondary)
                }
            }
            Spacer()
            if viewModel.isLoading {
                ProgressView().scaleEffect(0.6)
            }
            if viewModel.changeManager?.isEditable == true {
                AppButton(
                    LumiPluginLocalization.string("Add Row", bundle: .module),
                    systemImage: "plus",
                    style: .secondary,
                    size: .small,
                    action: { viewModel.addRow() }
                )
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }
            AppButton(
                LumiPluginLocalization.string("Refresh", bundle: .module),
                systemImage: "arrow.clockwise",
                style: .secondary,
                size: .small,
                action: { Task { await viewModel.loadTablePage() } }
            )
            AppButton(
                "Structure",
                systemImage: "list.bullet.rectangle",
                style: .secondary,
                size: .small,
                action: { viewModel.inspectorVisible = true }
            )
            AppButton(
                LumiPluginLocalization.string("SQL", bundle: .module),
                systemImage: "curlybraces",
                style: .ghost,
                size: .small,
                action: { viewModel.switchToQueryEditor() }
            )
        }
        .padding(.horizontal, 12)
        .frame(height: 48)
        .appSurface(style: .toolbar, cornerRadius: 0)
    }

    private var title: String {
        let conn = viewModel.selectedConfig?.name ?? ""
        let table = viewModel.openTableObject?.name ?? ""
        return table.isEmpty ? conn : "\(conn) / \(table)"
    }

    // MARK: - Pagination bar

    private var paginationBar: some View {
        let total = viewModel.tableRowCount ?? 0
        let pageCount = max(1, (total + viewModel.tablePageSize - 1) / viewModel.tablePageSize)
        let currentPage = min(viewModel.tablePage + 1, pageCount)

        return HStack(spacing: 8) {
            AppIconButton(systemImage: "chevron.left", label: "Prev", size: .compact) {
                Task { await viewModel.prevPage() }
            }
            .disabled(viewModel.tablePage == 0)

            Text(LumiPluginLocalization.string("Page", bundle: .module) + " \(currentPage) / \(pageCount.formatted())")
                .font(.appMicro)
                .foregroundStyle(.secondary)

            AppIconButton(systemImage: "chevron.right", label: "Next", size: .compact) {
                Task { await viewModel.nextPage() }
            }
            .disabled(currentPage >= pageCount)

            Spacer()

            Text(LumiPluginLocalization.string("Rows", bundle: .module) + ": \(rowRangeText(currentPage: viewModel.tablePage))")
                .font(.appMicro)
                .foregroundStyle(.secondary)

            Picker(LumiPluginLocalization.string("Page Size", bundle: .module), selection: pageSizeBinding) {
                ForEach(pageSizes, id: \.self) { size in
                    Text("\(size)").tag(size)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 90)
            .labelsHidden()
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
        .appSurface(style: .toolbar, cornerRadius: 0)
    }

    private var pageSizeBinding: Binding<Int> {
        Binding(
            get: { viewModel.tablePageSize },
            set: { newSize in Task { await viewModel.setPageSize(newSize) } }
        )
    }

    /// 当前页展示的行区间文本，如 "1–100"。
    private func rowRangeText(currentPage: Int) -> String {
        let pageSize = viewModel.tablePageSize
        let start = currentPage * pageSize + 1
        var end = start + pageSize - 1
        if let total = viewModel.tableRowCount { end = min(end, total) }
        if let result = viewModel.queryResult, result.rows.count < pageSize {
            end = start + result.rows.count - 1
        }
        return "\(start.formatted())–\(max(start, end).formatted())"
    }
}

#if DEBUG
#Preview("Table Data") {
    TableDataView(viewModel: DatabaseViewModel())
        .frame(width: 720, height: 460)
}
#endif
