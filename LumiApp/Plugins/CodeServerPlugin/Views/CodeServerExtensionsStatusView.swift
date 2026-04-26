import SwiftUI

/// Code Server 扩展状态栏视图
///
/// 在状态栏右侧显示已安装的扩展数量，点击弹出管理面板。
struct CodeServerExtensionsStatusView: View {
    @StateObject private var manager = CodeServerManager.shared

    var body: some View {
        Group {
            if !manager.isRunning {
                inactiveView
            } else {
                activeView
            }
        }
        .onAppear {
            if manager.isRunning && manager.installedExtensions.isEmpty {
                manager.loadInstalledExtensions()
            }
        }
        .onChange(of: manager.isRunning) { _, newValue in
            if newValue && manager.installedExtensions.isEmpty {
                manager.loadInstalledExtensions()
            } else if !newValue {
                manager.installedExtensions = []
            }
        }
    }

    // MARK: - Inactive View

    private var inactiveView: some View {
        StatusBarHoverContainer(
            detailView: ExtensionsInactiveDetailView(),
            id: "code-server-extensions-inactive"
        ) {
            HStack(spacing: 4) {
                Image(systemName: "puzzlepiece.extension")
                    .font(.system(size: 10))

                Text("Extensions")
                    .font(.system(size: 11))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .help("code-server 未运行，扩展管理不可用")
    }

    // MARK: - Active View

    private var activeView: some View {
        StatusBarHoverContainer(
            detailView: ExtensionsManagerDetailView(),
            id: "code-server-extensions-active"
        ) {
            HStack(spacing: 4) {
                Image(systemName: "puzzlepiece.extension")
                    .font(.system(size: 10))

                if manager.isLoadingExtensions {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 10, height: 10)
                } else {
                    Text("\(manager.installedExtensions.count)")
                        .font(.system(size: 11, weight: .medium))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .help("管理 code-server 扩展")
    }
}

// MARK: - Inactive Detail View

/// 未运行时的详情视图
struct ExtensionsInactiveDetailView: View {
    var body: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: "puzzlepiece.extension")
                    .font(.system(size: 16))
                    .foregroundColor(DesignTokens.Color.semantic.primary)

                Text("扩展管理")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)
            }

            Divider()

            Text("请先启动 code-server 以管理扩展")
                .font(.system(size: 12))
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(width: 300)
    }
}

// MARK: - Extensions Manager Detail View

/// 扩展管理详情视图
struct ExtensionsManagerDetailView: View {
    @StateObject private var manager = CodeServerManager.shared
    @State private var newExtensionId = ""
    @State private var isInstalling = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            // 标题栏
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: "puzzlepiece.extension")
                    .font(.system(size: 14))
                    .foregroundColor(DesignTokens.Color.semantic.primary)

                Text("扩展管理")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                Spacer()

                // 刷新按钮
                Button(action: {
                    manager.loadInstalledExtensions()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14))
                        .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                }
                .buttonStyle(.plain)
                .help("刷新扩展列表")
                .disabled(manager.isLoadingExtensions)
            }

            Divider()

            // 错误提示
            if let error = manager.extensionError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 10))
                        .foregroundColor(DesignTokens.Color.semantic.warning)
                    Text(error)
                        .font(.system(size: 10))
                        .foregroundColor(DesignTokens.Color.semantic.warning)
                        .lineLimit(2)
                }
                .padding(8)
                .background(DesignTokens.Color.adaptive.errorBackground(for: .dark))
                .cornerRadius(6)
            }

            // 扩展列表
            if manager.isLoadingExtensions {
                VStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("加载扩展列表...")
                        .font(.system(size: 12))
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                }
                .frame(maxWidth: .infinity, minHeight: 80)
            } else if manager.installedExtensions.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "puzzlepiece.extension")
                        .font(.system(size: 24))
                        .foregroundColor(DesignTokens.Color.semantic.textDisabled)

                    Text("未安装任何扩展")
                        .font(.system(size: 12))
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)

                    Text("点击下方按钮安装扩展")
                        .font(.system(size: 11))
                        .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                }
                .frame(maxWidth: .infinity, minHeight: 100)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(manager.installedExtensions) { ext in
                            ExtensionRowView(ext: ext)
                                .padding(.vertical, 6)
                        }
                    }
                }
                .frame(maxHeight: 200)
            }

            Divider()

            // 安装新扩展
            HStack(spacing: 8) {
                TextField("输入扩展 ID", text: $newExtensionId)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))

                Button(action: {
                    installNewExtension()
                }) {
                    if isInstalling {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 12, height: 12)
                    } else {
                        Image(systemName: "plus")
                            .font(.system(size: 12))
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(newExtensionId.isEmpty || isInstalling)
                .help("安装扩展")
            }
        }
        .padding()
        .frame(width: 300)
        .task(id: manager.installedExtensions) {
            // 当扩展列表变化时隐藏安装进度
            if !isInstalling { return }
            isInstalling = false
        }
    }

    private func installNewExtension() {
        guard !newExtensionId.isEmpty else { return }
        isInstalling = true

        Task {
            let success = await manager.installExtension(newExtensionId)
            if success {
                newExtensionId = ""
            } else {
                await MainActor.run {
                    isInstalling = false
                }
            }
        }
    }
}

// MARK: - Extension Row View

/// 单个扩展行视图
struct ExtensionRowView: View {
    let ext: CodeServerExtension
    @StateObject private var manager = CodeServerManager.shared
    @State private var isUninstalling = false

    var body: some View {
        HStack(spacing: 8) {
            // 图标 + 名称
            VStack(alignment: .leading, spacing: 2) {
                Text(ext.id)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                    .lineLimit(1)

                if let version = ext.version {
                    Text("v\(version)")
                        .font(.system(size: 10))
                        .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                }
            }

            Spacer()

            // 卸载按钮
            Button(action: {
                uninstall()
            }) {
                if isUninstalling {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 10, height: 10)
                } else {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                }
            }
            .buttonStyle(.plain)
            .help("卸载扩展")
            .disabled(isUninstalling)
        }
        .padding(.horizontal, 4)
    }

    private func uninstall() {
        isUninstalling = true

        Task {
            _ = await manager.uninstallExtension(ext.id)
            await MainActor.run {
                isUninstalling = false
            }
        }
    }
}
