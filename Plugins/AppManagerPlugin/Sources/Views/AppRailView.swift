import LumiUI
import SwiftUI

/// 应用管理器侧边栏：搜索、统计、应用列表。
///
/// 由 `AppManagerPlugin` 注册为 `PanelRailTabItem`，
/// 仅在 app-manager ViewContainer 中可见。
struct AppRailView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme
    @ObservedObject var viewModel: AppManagerViewModel

    init(viewModel: AppManagerViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        VStack(spacing: 0) {
            // 顶部工具栏
            toolbar

            GlassDivider()

            // 错误提示横幅
            if let errorMessage = viewModel.errorMessage {
                AppErrorBanner(
                    message: LocalizedStringKey(errorMessage),
                    retryTitle: LocalizedStringKey(PluginAppManagerLocalization.string("Retry")),
                    onRetry: {
                        viewModel.errorMessage = nil
                        viewModel.refresh()
                    }
                )
            }

            // 应用列表
            if viewModel.isLoading {
                AppLoadingOverlay(
                    message: LocalizedStringKey(PluginAppManagerLocalization.string("Scanning applications...")),
                    size: .large
                )
            } else if viewModel.filteredApps.isEmpty {
                AppEmptyState(
                    icon: "app.dashed",
                    title: PluginAppManagerLocalization.string("No applications found"),
                    description: viewModel.searchText.isEmpty
                        ? nil
                        : PluginAppManagerLocalization.string("Try other search keywords")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                appList
            }

            GlassDivider()

            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            if viewModel.installedApps.isEmpty {
                Task {
                    await viewModel.loadFromCache()
                    if viewModel.installedApps.isEmpty {
                        viewModel.refresh()
                    }
                }
            }
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 8) {
            AppSearchBar(
                text: $viewModel.searchText,
                placeholder: LocalizedStringKey(PluginAppManagerLocalization.string("Search Apps"))
            )

            AppIconButton(systemImage: "arrow.clockwise") {
                guard !viewModel.isLoading else { return }
                viewModel.refresh()
            }
            .help(PluginAppManagerLocalization.string("Refresh"))
        }
        .padding()
        .background(Material.regularMaterial)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Text(PluginAppManagerLocalization.format("%lld Apps", viewModel.installedApps.count))
                .font(.appBodyEmphasized)
                .foregroundColor(theme.textSecondary)

            Text("·")
                .foregroundColor(theme.textSecondary)

            Text(PluginAppManagerLocalization.format("Total Size: %@", viewModel.formattedTotalSize))
                .font(.appBodyEmphasized)
                .foregroundColor(theme.textSecondary)

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .frame(height: 40)
        .background(Material.regularMaterial)
    }

    // MARK: - App List

    private var appList: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(viewModel.filteredApps) { app in
                    AppListRow(isSelected: viewModel.selectedApp?.id == app.id, action: {
                        viewModel.selectedApp = app
                    }) {
                        AppRow(app: app, viewModel: viewModel)
                    }
                    .contextMenu {
                        AppContextMenuRow(
                            LocalizedStringKey(PluginAppManagerLocalization.string("Show in Finder")),
                            systemImage: "folder",
                            action: { viewModel.revealInFinder(app) }
                        )

                        AppContextMenuRow(
                            LocalizedStringKey(PluginAppManagerLocalization.string("Open")),
                            systemImage: "play.fill",
                            action: { viewModel.openApp(app) }
                        )
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .scrollContentBackground(.hidden)
    }
}

#if DEBUG
#Preview {
    AppRailView(viewModel: AppManagerViewModel())
        .frame(width: 260, height: 500)
}
#endif
