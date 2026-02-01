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
                viewModel.refresh()
            }
        }
        .alert("卸载确认", isPresented: $showUninstallAlert, presenting: viewModel.selectedApp) { app in
            Button("取消", role: .cancel) {
                viewModel.cancelSelection()
            }
            Button("卸载", role: .destructive) {
                Task {
                    await viewModel.uninstallApp(app)
                }
            }
        } message: { app in
            Text("确定要卸载「\(app.displayName)」吗？\n\n应用将被移到废纸篓。")
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
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            Text("正在扫描应用...")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "app.dashed")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("没有找到应用")
                .font(.title3)
                .foregroundStyle(.secondary)

            if !viewModel.searchText.isEmpty {
                Text("请尝试其他搜索关键词")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

/// 应用行视图
struct AppRow: View {
    let app: AppModel
    @ObservedObject var viewModel: AppManagerViewModel

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            // 应用图标
            if let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 48, height: 48)
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 48, height: 48)
                    .overlay {
                        Image(systemName: "app")
                            .foregroundStyle(.secondary)
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                // 应用名称
                Text(app.displayName)
                    .font(.headline)

                // Bundle ID 和版本
                HStack(spacing: 8) {
                    if let identifier = app.bundleIdentifier {
                        Text(identifier)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let version = app.version {
                        Text("•")
                            .foregroundStyle(.secondary)

                        Text(version)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // 大小
                Text(app.formattedSize)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // 操作按钮（悬停时显示）
            if isHovering {
                HStack(spacing: 8) {
                    Button(action: {
                        viewModel.revealInFinder(app)
                    }) {
                        Image(systemName: "folder")
                    }
                    .buttonStyle(.bordered)
                    .help("在 Finder 中显示")

                    Button(action: {
                        viewModel.openApp(app)
                    }) {
                        Image(systemName: "play.fill")
                    }
                    .buttonStyle(.bordered)
                    .help("打开应用")

                    Button(action: {
                        viewModel.selectedApp = app
                    }) {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderedProminent)
                    .help("卸载应用")
                }
                .transition(.opacity)
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .onHover { hovering in
            isHovering = hovering
        }
        .contextMenu {
            Button("在 Finder 中显示") {
                viewModel.revealInFinder(app)
            }

            Button("打开") {
                viewModel.openApp(app)
            }

            Divider()

            Button("卸载", role: .destructive) {
                viewModel.selectedApp = app
            }
        }
    }
}

#Preview {
    AppManagerView()
        .frame(width: 800, height: 600)
}
