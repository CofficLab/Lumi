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
                
                GlassDivider()
                
                // 应用列表
                if viewModel.isLoading {
                    loadingView
                } else if viewModel.filteredApps.isEmpty {
                    emptyView
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
        .alert(PluginAppManagerLocalization.string("Confirm Uninstall"), isPresented: $viewModel.showUninstallConfirmation) {
            Button(PluginAppManagerLocalization.string("Cancel"), role: .cancel) { }
            Button(PluginAppManagerLocalization.string("Uninstall"), role: .destructive) {
                viewModel.deleteSelectedFiles()
            }
        } message: {
            Text(PluginAppManagerLocalization.string("Are you sure you want to delete the selected files? This action cannot be undone."))
        }
        .alert(PluginAppManagerLocalization.string("Error"), isPresented: Binding<Bool>(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button(PluginAppManagerLocalization.string("OK")) {
                viewModel.errorMessage = nil
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
    }
    
    private var toolbar: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 第一行：搜索
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(theme.textSecondary)
                TextField(
                    PluginAppManagerLocalization.string("Search Apps"),
                    text: $viewModel.searchText
                )
                .textFieldStyle(.roundedBorder)
            }

            // 第二行：统计 + 刷新
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

                AppButton(PluginAppManagerLocalization.string("Refresh"), style: .secondary, fillsWidth: true, action: { viewModel.refresh() })
                .disabled(viewModel.isLoading)
            }
        }
        .padding()
        .background(Material.regularMaterial)
    }
    
    private var loadingView: some View {
        AppManagerLoadingView()
    }
    
    private var emptyView: some View {
        AppManagerEmptyView(searchText: viewModel.searchText)
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
