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
            
            // Right: Details
            detailView
                .frame(minWidth: 400, maxWidth: .infinity)
                .infiniteHeight()
        }
        .infinite()
        .navigationTitle(String(localized: "App Manager", table: "AppManager"))
        .searchable(text: $viewModel.searchText, prompt: String(localized: "Search Apps", table: "AppManager"))
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
                                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                        }
                        
                        VStack(alignment: .leading) {
                            Text(app.displayName)
                                .font(.title)
                                .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                            Text(app.bundleIdentifier ?? "Unknown Bundle ID")
                                .font(.caption)
                                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                            Text(app.bundleURL.path)
                                .font(.caption2)
                                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                    .padding()
                    
                    GlassDivider()
                    
                    // Related Files List
                    if viewModel.isScanningFiles {
                        Spacer()
                        ProgressView(String(localized: "Scanning related files...", table: "AppManager"))
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
                                            .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                                        Text(file.path)
                                            .font(.caption2)
                                            .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }
                                    
                                    Spacer()
                                    
                                    Text(formatBytes(file.size))
                                        .font(.monospacedDigit(.caption)())
                                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                                }
                            }
                        }
                    }
                    
                    GlassDivider()
                    
                    // Footer Action
                    HStack {
                        Text(String(localized: "Selected: \(formatBytes(viewModel.totalSelectedSize))", table: "AppManager"))
                            .font(.headline)
                            .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                        Spacer()

                        GlassButton(title: LocalizedStringKey("Uninstall Selected"), style: .danger) {
                            viewModel.showUninstallConfirmation = true
                        }
                        .controlSize(.large)
                        .disabled(viewModel.selectedFileIds.isEmpty || viewModel.isDeleting)
                    }
                    .padding()
                }
            } else {
                ContentUnavailableView(String(localized: "Select an App", table: "AppManager"), systemImage: "hand.tap")
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
        .withNavigation(AppManagerPlugin.navigationId)
        .inRootView()
        .withDebugBar()
}
