import SwiftUI
import KernelLumi
import LumiUI

/// 侧边栏连接列表视图。
///
/// 复用 ``AppListRow`` 的行样式（与 ``DatabaseKeyRow`` 一致），
/// 行点击即 ``viewModel.connect(config:)``；连接成功后由调用方触发翻牌回到数据浏览。
///
/// 风格参考 `ConnectionPopoverView`，但作为侧边栏列表使用：
/// - 顶部 ``DatabaseSidebarHeaderBar``（标题 Connections + 加号 + 切换）；
/// - 列表项展示图标、连接名、类型/host 副标题；当前连接显示绿色圆点；
/// - 右键上下文菜单提供「Delete」入口（与 TablePlus、Navicat 一致）。
struct ConnectionsListView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @ObservedObject var viewModel: DatabaseViewModel

    /// 点击切换按钮（数据/连接列表）的回调，由 ``SidebarView`` 传入。
    let onToggleMode: () -> Void

    /// Add Connection 表单是否展示。
    @State private var showAddConfigSheet: Bool = false
    /// 正在编辑的连接；非 nil 时弹出编辑表单。
    @State private var editingConfig: DatabaseConfig?

    var body: some View {
        VStack(spacing: 0) {
            DatabaseSidebarHeaderBar(
                title: LumiPluginLocalization.string("Connections", bundle: .module),
                systemImage: "cylinder.split.1x2",
                onAdd: { showAddConfigSheet = true },
                onToggleMode: onToggleMode,
                toggleMode: viewModel.sidebarMode
            )

            if viewModel.configs.isEmpty {
                emptyState
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(viewModel.configs, id: \.id) { config in
                            connectionRow(config)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
                .scrollIndicators(.hidden)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                footer
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showAddConfigSheet) {
            ConnectionFormView(viewModel: viewModel, isPresented: $showAddConfigSheet)
        }
        .sheet(item: $editingConfig) { config in
            ConnectionFormView(viewModel: viewModel, isPresented: Binding(
                get: { editingConfig != nil },
                set: { if !$0 { editingConfig = nil } }
            ), editing: config)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            SidebarEmptyView(
                systemImage: "cylinder.split.1x2",
                title: LumiPluginLocalization.string("No saved connections", bundle: .module),
                description: LumiPluginLocalization.string("Click + to add a new connection.", bundle: .module)
            )
            AppButton(
                LumiPluginLocalization.string("Add Connection", bundle: .module),
                systemImage: "plus",
                style: .secondary,
                size: .small,
                action: { showAddConfigSheet = true }
            )
            .padding(.top, 4)
        }
    }

    // MARK: - Row

    private func connectionRow(_ config: DatabaseConfig) -> some View {
        let isSelected = viewModel.selectedConfig?.id == config.id
        let isConnected = isSelected && viewModel.isConnected

        return AppListRow(isSelected: isSelected, action: {
            Task { await viewModel.connect(config: config) }
        }) {
            HStack(spacing: 8) {
                Image(systemName: icon(for: config.type))
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 1) {
                    Text(config.name)
                        .font(.appMicroEmphasized)
                        .foregroundColor(theme.textPrimary)
                        .lineLimit(1)
                    Text(detailLine(for: config))
                        .font(.appCaption)
                        .foregroundColor(theme.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                statusIndicator(isSelected: isSelected, isConnected: isConnected)
            }
        }
        .contextMenu {
            Button {
                editingConfig = config
            } label: {
                Label(LumiPluginLocalization.string("Edit", bundle: .module), systemImage: "pencil")
            }
            Button(role: .destructive) {
                viewModel.removeConfig(config)
            } label: {
                Label(LumiPluginLocalization.string("Delete", bundle: .module), systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private func statusIndicator(isSelected: Bool, isConnected: Bool) -> some View {
        if viewModel.isLoading && isSelected {
            ProgressView().scaleEffect(0.5).frame(width: 12, height: 12)
        } else if isConnected {
            Circle().fill(theme.success).frame(width: 8, height: 8)
        } else if isSelected {
            Circle().stroke(theme.appSubtleBorder, lineWidth: 1).frame(width: 8, height: 8)
        }
    }

    private func icon(for type: DatabaseType) -> String {
        switch type {
        case .sqlite: return "doc.text.fill"
        case .mysql: return "cylinder.split.1x2.fill"
        case .postgresql: return "cylinder.split.1x2"
        case .redis: return "memorychip"
        }
    }

    private func detailLine(for config: DatabaseConfig) -> String {
        switch config.type {
        case .sqlite:
            return "SQLite · \(config.database)"
        case .redis:
            return "Redis · \(config.host ?? "127.0.0.1"):\(config.port ?? 6379)"
        case .mysql:
            return "MySQL · \(config.host ?? "127.0.0.1"):\(config.port ?? 3306)/\(config.database)"
        case .postgresql:
            return "PostgreSQL · \(config.host ?? "127.0.0.1"):\(config.port ?? 5432)/\(config.database)"
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 8) {
            AppButton(
                LumiPluginLocalization.string("Add Connection", bundle: .module),
                systemImage: "plus",
                style: .ghost,
                fillsWidth: true,
                action: { showAddConfigSheet = true }
            )
            if viewModel.isConnected {
                AppButton(
                    LumiPluginLocalization.string("Disconnect", bundle: .module),
                    systemImage: "power",
                    style: .secondary,
                    action: { Task { await viewModel.disconnect() } }
                )
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }
}

#if DEBUG
#Preview("Connections") {
    ConnectionsListView(viewModel: DatabaseViewModel(), onToggleMode: {})
        .frame(width: 260, height: 360)
}
#endif