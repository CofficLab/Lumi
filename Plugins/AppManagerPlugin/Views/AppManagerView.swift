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
            .frame(minWidth: 400, maxWidth: .infinity)
            .infiniteHeight()
            
            // Right: Details
            detailView
                .frame(minWidth: 400, maxWidth: .infinity)
                .infiniteHeight()
        }
        .infinite()
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
        .alert("确认卸载", isPresented: $viewModel.showUninstallConfirmation) {
            Button("取消", role: .cancel) { }
            Button("卸载", role: .destructive) {
                viewModel.deleteSelectedFiles()
            }
        } message: {
            Text("确定要删除选中的文件吗？此操作不可撤销。")
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
        List(selection: $viewModel.selectedApp) {
            ForEach(viewModel.filteredApps) { app in
                AppRow(app: app, viewModel: viewModel)
                    .tag(app)
                    .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
            }
        }
        .listStyle(.inset)
        .infinite()
    }
    
    private var detailView: some View {
        VStack(spacing: 0) {
            if let app = viewModel.selectedApp {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    HStack(spacing: 16) {
                        if let icon = app.icon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 64, height: 64)
                        } else {
                            Image(systemName: "app.fill")
                                .resizable()
                                .frame(width: 64, height: 64)
                                .foregroundStyle(.secondary)
                        }
                        
                        VStack(alignment: .leading) {
                            Text(app.displayName)
                                .font(.title)
                            Text(app.bundleIdentifier ?? "Unknown Bundle ID")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(app.bundleURL.path)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                    .padding()
                    
                    Divider()
                    
                    // Related Files List
                    if viewModel.isScanningFiles {
                        Spacer()
                        ProgressView("正在扫描关联文件...")
                        Spacer()
                    } else {
                        List {
                            ForEach(viewModel.relatedFiles) { file in
                                HStack {
                                    Toggle("", isOn: Binding(
                                        get: { viewModel.selectedFileIds.contains(file.id) },
                                        set: { _ in viewModel.toggleFileSelection(file.id) }
                                    ))
                                    .toggleStyle(.checkbox)
                                    .labelsHidden()
                                    
                                    VStack(alignment: .leading) {
                                        Text(file.type.displayName)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(file.path)
                                            .font(.caption2)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }
                                    
                                    Spacer()
                                    
                                    Text(formatBytes(file.size))
                                        .font(.monospacedDigit(.caption)())
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Footer Action
                    HStack {
                        Text("已选: \(formatBytes(viewModel.totalSelectedSize))")
                            .font(.headline)
                        
                        Spacer()
                        
                        Button(role: .destructive) {
                            viewModel.showUninstallConfirmation = true
                        } label: {
                            Text("卸载选中项")
                                .padding(.horizontal, 8)
                        }
                        .controlSize(.large)
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.selectedFileIds.isEmpty || viewModel.isDeleting)
                    }
                    .padding()
                }
            } else {
                ContentUnavailableView("选择应用", systemImage: "hand.tap")
            }
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
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
