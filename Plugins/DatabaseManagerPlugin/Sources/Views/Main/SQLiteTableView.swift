import SwiftUI
import LumiUI
import LumiKernel

/// ``MainView`` 的 SQLite 数据浏览视图。
///
/// 当连接类型为 SQLite 且已选中某张表（或尚未选表）时显示：
/// - 顶部工具栏：表名 + 「First 50 rows」副标题 + Refresh 按钮 + Loading 转圈；
/// - 下方数据区：复用 ``MainQueryResultSectionView`` 渲染。
///
/// 之所以单独成视图，是因为它只覆盖 SQLite 类型的连接（见
/// `MainView.connectedContent` 中 `viewModel.selectedConfig?.type == .sqlite` 的分支），
/// 其它类型仍由 SQL 编辑器路径处理。
struct SQLiteTableView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    // MARK: - Properties

    @ObservedObject var viewModel: DatabaseViewModel

    // MARK: - Initialization

    init(viewModel: DatabaseViewModel) {
        self.viewModel = viewModel
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            AppDivider()
            QueryResultSectionView(viewModel: viewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    // MARK: - Subviews

    /// 顶栏标题：当前连接的名称；选中具体表时显示「连接名 / 表名」。
    private var connectionTitle: String {
        let name = viewModel.selectedConfig?.name ?? LumiPluginLocalization.string("Select a table", bundle: .module)
        if let table = viewModel.selectedSQLiteTable {
            return "\(name) / \(table)"
        }
        return name
    }

    private var toolbar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(connectionTitle)
                    .font(.appBodyEmphasized)
                    .foregroundColor(theme.textPrimary)
                if viewModel.selectedSQLiteTable != nil {
                    Text(LumiPluginLocalization.string("First 50 rows", bundle: .module))
                        .font(.appCaption)
                        .foregroundColor(theme.textSecondary)
                }
            }
            Spacer()
            if viewModel.selectedSQLiteTable != nil {
                AppButton("Refresh", systemImage: "arrow.clockwise", style: .secondary, size: .small, action: {
                    guard let table = viewModel.selectedSQLiteTable else { return }
                    Task { await viewModel.openSQLiteTable(table) }
                })
            }
            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(0.6)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 48)
        .appSurface(style: .toolbar, cornerRadius: 0)
    }
}

// MARK: - 预览

#if DEBUG
#Preview("SQLite Table") {
    SQLiteTableView(viewModel: DatabaseViewModel())
        .frame(width: 700, height: 400)
}
#endif
