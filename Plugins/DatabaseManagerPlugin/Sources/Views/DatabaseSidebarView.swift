import SwiftUI
import LumiUI
import LumiKernel

/// Database 侧边栏：显示 Tables（SQLite）或 Keys（Redis）浏览器。
///
/// 由 ``DatabaseManagerPlugin`` 注册为 RailView 的 `PanelRailTabItem`，
/// 仅在 database-manager ViewContainer 中可见。
public struct DatabaseSidebarView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @ObservedObject var viewModel: DatabaseViewModel

    public init(viewModel: DatabaseViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Group {
            if viewModel.selectedConfig?.type == .sqlite {
                tablesBrowser
            } else if viewModel.selectedConfig?.type == .redis {
                keysBrowser
            }
        }
        .padding(8)
    }

    private var keysBrowser: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(LumiPluginLocalization.string("Keys", bundle: .module))
                        .font(.appBodyEmphasized)
                        .foregroundColor(theme.textPrimary)
                    Spacer()
                    AppButton("Load", systemImage: "arrow.clockwise", style: .secondary, size: .small, action: { Task { await viewModel.loadRedisKeys() } })
                }
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(viewModel.redisKeys, id: \.self) { key in
                            AppListRow(isSelected: false, action: { Task { await viewModel.openRedisKey(key) } }) {
                                HStack {
                                    Image(systemName: "key")
                                    Text(key)
                                        .lineLimit(1)
                                    Spacer()
                                }
                            }
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .frame(maxHeight: .infinity)
            }
        }
    }

    private var tablesBrowser: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(LumiPluginLocalization.string("Tables", bundle: .module))
                        .font(.appBodyEmphasized)
                        .foregroundColor(theme.textPrimary)
                    Spacer()
                    AppButton("Load", systemImage: "arrow.clockwise", style: .secondary, size: .small, action: { Task { await viewModel.loadSQLiteTables() } })
                }
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(viewModel.sqliteTables, id: \.self) { table in
                            AppListRow(
                                isSelected: viewModel.selectedSQLiteTable == table,
                                action: { Task { await viewModel.openSQLiteTable(table) } }
                            ) {
                                HStack(spacing: 8) {
                                    Image(systemName: "tablecells")
                                    Text(table)
                                        .lineLimit(1)
                                    Spacer()
                                    if viewModel.selectedSQLiteTable == table {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(Color.accentColor)
                                    }
                                }
                            }
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .frame(maxHeight: .infinity)
            }
        }
    }
}
