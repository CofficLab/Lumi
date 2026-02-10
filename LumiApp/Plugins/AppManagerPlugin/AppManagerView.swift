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
        .navigationTitle("App Manager")
        .searchable(text: $viewModel.searchText, prompt: "Search Apps")
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
        .alert("Confirm Uninstall", isPresented: $viewModel.showUninstallConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Uninstall", role: .destructive) {
                viewModel.deleteSelectedFiles()
            }
        } message: {
            Text("Are you sure you want to delete the selected files? This action cannot be undone.")
        }
        .alert("Error", isPresented: Binding<Bool>(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") {
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
                Text("\(viewModel.installedApps.count) Apps")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Text("Total Size: \(viewModel.formattedTotalSize)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button(action: {
                viewModel.refresh()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                    Text("Refresh")
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
            }
        }
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
                        ProgressView("Scanning related files...")
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
                        Text("Selected: \(formatBytes(viewModel.totalSelectedSize))")
                            .font(.headline)
                        
                        Spacer()
                        
                        Button(role: .destructive) {
                            viewModel.showUninstallConfirmation = true
                        } label: {
                            Text("Uninstall Selected")
                                .padding(.horizontal, 8)
                        }
                        .controlSize(.large)
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.selectedFileIds.isEmpty || viewModel.isDeleting)
                    }
                    .padding()
                }
            } else {
                ContentUnavailableView("Select an App", systemImage: "hand.tap")
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
