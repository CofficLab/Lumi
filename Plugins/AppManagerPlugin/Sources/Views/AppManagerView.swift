import LumiUI
import SwiftUI

/// 应用管理器视图
struct AppManagerView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @StateObject private var viewModel = AppManagerViewModel()
    
    var body: some View {
        HSplitView {
            // Left: App List
            VStack(spacing: 0) {
                // 顶部工具栏
                toolbar
                
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
                
                GlassDivider()
                
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
                } else {
                    appList
                }
            }
            .frame(minWidth: 400, maxWidth: .infinity)
            .frame(maxHeight: .infinity)
            
            // Right: Details
            detailView
                .frame(minWidth: 400, maxWidth: .infinity)
                .frame(maxHeight: .infinity)
        }
        .frame(maxHeight: .infinity)
        .frame(maxWidth: .infinity)
        .navigationTitle(PluginAppManagerLocalization.string("App Manager"))
        .onChange(of: viewModel.selectedApp) { _, newApp in
            if let app = newApp {
                viewModel.scanRelatedFiles(for: app)
            } else {
                viewModel.clearRelatedFiles()
            }
        }
        .onAppear {
            if viewModel.installedApps.isEmpty {
                // 先尝试从缓存加载
                Task {
                    await viewModel.loadFromCache()
                    // 如果缓存为空，则进行完整扫描
                    if viewModel.installedApps.isEmpty {
                        viewModel.refresh()
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .appManagerRefreshRequested)) { _ in
            guard !viewModel.isLoading else { return }
            viewModel.refresh()
        }
        .alert(PluginAppManagerLocalization.string("Confirm Uninstall"), isPresented: $viewModel.showUninstallConfirmation) {
            Button(PluginAppManagerLocalization.string("Cancel"), role: .cancel) { }
            Button(PluginAppManagerLocalization.string("Uninstall"), role: .destructive) {
                viewModel.deleteSelectedFiles()
            }
        } message: {
            Text(PluginAppManagerLocalization.string("Are you sure you want to delete the selected files? This action cannot be undone."))
        }
    }
    
    private var toolbar: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 第一行：搜索
            AppSearchBar(
                text: $viewModel.searchText,
                placeholder: LocalizedStringKey(PluginAppManagerLocalization.string("Search Apps"))
            )

            // 第二行：统计
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(PluginAppManagerLocalization.format("%lld Apps", viewModel.installedApps.count))
                        .font(.appCallout)
                        .foregroundColor(theme.textSecondary)

                    Text(PluginAppManagerLocalization.format("Total Size: %@", viewModel.formattedTotalSize))
                        .font(.appCaption)
                        .foregroundColor(theme.textSecondary)
                }

                Spacer()
            }
        }
        .padding()
        .background(Material.regularMaterial)
    }
    
    private var appList: some View {
        List(selection: $viewModel.selectedApp) {
            ForEach(viewModel.filteredApps) { app in
                AppRow(app: app, viewModel: viewModel)
                    .tag(app)
            }
        }
    }
    
    private var detailView: some View {
        AppManagerDetailView(viewModel: viewModel)
    }
}
