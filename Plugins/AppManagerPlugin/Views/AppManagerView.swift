import SwiftUI

/// 应用管理器视图
struct AppManagerView: View {
    @StateObject private var viewModel = AppManagerViewModel()
    @State private var showUninstallAlert = false

    var body: some View {
        VStack(spacing: 0) {
            // 顶部工具栏
            toolbar

            Divider()

            // 应用列表
            if viewModel.isLoading {
                loadingView
            } else if viewModel.filteredApps.isEmpty {
                emptyView
            } else {
                appList
            }
        }
        .navigationTitle("应用管理")
        .searchable(text: $viewModel.searchText, prompt: "搜索应用")
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
        .alert("卸载确认", isPresented: $viewModel.showUninstallConfirmation, presenting: viewModel.selectedApp) { app in
            Button("取消", role: .cancel) {
                viewModel.cancelSelection()
            }
            Button("卸载", role: .destructive) {
                Task {
                    await viewModel.uninstallApp(app)
                }
            }
        } message: { app in
            Text("确定要卸载「\(app.displayName)」吗？\n\n应用及其关联文件将被移到废纸篓。")
        }
        .alert("错误", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("确定") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
    }

    private var toolbar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(viewModel.installedApps.count) 个应用")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("总大小: \(viewModel.formattedTotalSize)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: {
                viewModel.refresh()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                    Text("刷新")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isLoading)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var loadingView: some View {
        AppManagerLoadingView()
    }

    private var emptyView: some View {
        AppManagerEmptyView(searchText: viewModel.searchText)
    }

    private var appList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.filteredApps) { app in
                    AppRow(app: app, viewModel: viewModel)
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .hideTabPicker()
        .withNavigation(AppManagerPlugin.navigationId)
        .inRootView()
        .withDebugBar()
}
