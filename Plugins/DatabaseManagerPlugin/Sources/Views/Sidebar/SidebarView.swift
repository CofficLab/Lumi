import SwiftUI
import LumiUI
import LumiKernel

/// Database 侧边栏：显示 Tables（SQLite）或 Keys（Redis）浏览器。
///
/// 由 ``DatabaseManagerPlugin`` 注册为 RailView 的 `PanelRailTabItem`，
/// 仅在 database-manager ViewContainer 中可见。
///
/// 样式与 `ConversationListPlugin.ListView` 的 Rail 列表保持一致：
/// - 顶部 `DatabaseSidebarHeaderBar`：icon + caption 标题 + Reload 按钮
/// - `LazyVStack` 列表，每行使用 ``DatabaseTableRow`` / ``DatabaseKeyRow``
/// - `padding(.horizontal, 8)` / `padding(.vertical, 4)` 列表内边距
/// - 不再使用 `AppCard` 包裹整个内容，背景沿用 RailView 自带的 surface
public struct SidebarView: View {

    // MARK: - Properties

    @ObservedObject var viewModel: DatabaseViewModel

    // MARK: - Initialization

    public init(viewModel: DatabaseViewModel) {
        self.viewModel = viewModel
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            switch viewModel.selectedConfig?.type {
            case .sqlite:
                tablesBrowser
            case .redis:
                keysBrowser
            default:
                emptyHint
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Browsers

    private var tablesBrowser: some View {
        VStack(spacing: 0) {
            DatabaseSidebarHeaderBar(
                title: LumiPluginLocalization.string("Tables", bundle: .module),
                systemImage: "tablecells",
                onLoad: { Task { await viewModel.loadSQLiteTables() } }
            )

            if viewModel.sqliteTables.isEmpty {
                SidebarEmptyView(
                    systemImage: "tablecells",
                    title: LumiPluginLocalization.string("No tables", bundle: .module),
                    description: LumiPluginLocalization.string("Click Reload to refresh the table list.", bundle: .module)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(viewModel.sqliteTables, id: \.self) { table in
                            DatabaseTableRow(
                                tableName: table,
                                isSelected: viewModel.selectedSQLiteTable == table,
                                onSelect: {
                                    Task { await viewModel.openSQLiteTable(table) }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
                .scrollIndicators(.hidden)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var keysBrowser: some View {
        VStack(spacing: 0) {
            DatabaseSidebarHeaderBar(
                title: LumiPluginLocalization.string("Keys", bundle: .module),
                systemImage: "key",
                onLoad: { Task { await viewModel.loadRedisKeys() } }
            )

            if viewModel.redisKeys.isEmpty {
                SidebarEmptyView(
                    systemImage: "key",
                    title: LumiPluginLocalization.string("No keys", bundle: .module),
                    description: LumiPluginLocalization.string("Click Reload to refresh the key list.", bundle: .module)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(viewModel.redisKeys, id: \.self) { key in
                            DatabaseKeyRow(key: key) {
                                Task { await viewModel.openRedisKey(key) }
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
                .scrollIndicators(.hidden)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// 未连接到任何数据库时的占位视图。
    /// 仅占位，不显示任何列表内容。
    private var emptyHint: some View {
        SidebarEmptyView(
            systemImage: "cylinder.split.1x2",
            title: LumiPluginLocalization.string("No database connected", bundle: .module),
            description: LumiPluginLocalization.string("Use the toolbar button to add or pick a connection.", bundle: .module)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#if DEBUG
#Preview("Sidebar") {
    SidebarView(viewModel: DatabaseViewModel())
        .frame(width: 260, height: 400)
}
#endif
