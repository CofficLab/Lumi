import SwiftUI

/// 应用管理器视图
struct AppManagerView: View {
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
            .infiniteHeight()
            .ignoresSafeArea()
            
            // Right: Details
            detailView
                .frame(minWidth: 400, maxWidth: .infinity)
                .infiniteHeight()
        }
        .infinite()
        .ignoresSafeArea()
        .navigationTitle(String(localized: "App Manager", table: "AppManager"))
        .onChange(of: viewModel.selectedApp) { _, newApp in
            if let app = newApp {
                viewModel.scanRelatedFiles(for: app)
            } else {
                viewModel.relatedFiles = []
                viewModel.selectedFileIds = []
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
        .alert(String(localized: "Confirm Uninstall", table: "AppManager"), isPresented: $viewModel.showUninstallConfirmation) {
            Button(String(localized: "Cancel", table: "AppManager"), role: .cancel) { }
            Button(String(localized: "Uninstall", table: "AppManager"), role: .destructive) {
                viewModel.deleteSelectedFiles()
            }
        } message: {
            Text(String(localized: "Are you sure you want to delete the selected files? This action cannot be undone."))
        }
        .alert(String(localized: "Error", table: "AppManager"), isPresented: Binding<Bool>(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button(String(localized: "OK", table: "AppManager")) {
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
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                TextField(
                    String(localized: "Search Apps", table: "AppManager"),
                    text: $viewModel.searchText
                )
                .textFieldStyle(.roundedBorder)
            }

            // 第二行：统计 + 刷新
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "\(viewModel.installedApps.count) Apps", table: "AppManager"))
                        .font(.subheadline)
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)

                    Text(String(localized: "Total Size: \(viewModel.formattedTotalSize)", table: "AppManager"))
                        .font(.caption)
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                }

                Spacer()

                GlassButton(title: LocalizedStringKey("Refresh"), style: .secondary) {
                    viewModel.refresh()
                }
                .disabled(viewModel.isLoading)
            }
        }
        .padding()
        .background(DesignTokens.Material.glass)
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

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .withNavigation(AppManagerPlugin.navigationId)
        .inRootView()
        .withDebugBar()
}
