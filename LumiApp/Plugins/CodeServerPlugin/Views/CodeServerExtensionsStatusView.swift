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
    }
}

// MARK: - Extensions Manager Detail View

/// 扩展管理详情视图
struct ExtensionsManagerDetailView: View {
    @StateObject private var manager = CodeServerManager.shared
    @State private var selectedTab: ExtensionTab = .market

    enum ExtensionTab: String, CaseIterable {
        case market = "市场"
        case installed = "已安装"
    }

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

            // Tab 切换
            HStack(spacing: 0) {
                ForEach(ExtensionTab.allCases, id: \.self) { tab in
                    TabButton(
                        title: tab.rawValue,
                        isSelected: selectedTab == tab,
                        action: { selectedTab = tab }
                    )
                }
            }
            .background(Color.gray.opacity(0.1))
            .cornerRadius(6)

            Divider()

            // 错误提示
            if let error = manager.extensionError {
                ErrorBanner(message: error)
            }

            // 内容区域
            Group {
                switch selectedTab {
                case .market:
                    MarketSearchView()
                case .installed:
                    InstalledExtensionsView()
                }
            }
        }
        .padding()
        .frame(width: 400, height: 450)
    }
}

// MARK: - Tab Button

struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? DesignTokens.Color.semantic.primary : DesignTokens.Color.semantic.textSecondary)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(isSelected ? Color.gray.opacity(0.2) : Color.clear)
        .cornerRadius(4)
        .contentShape(Rectangle())
    }
}

// MARK: - Error Banner

struct ErrorBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 10))
                .foregroundColor(DesignTokens.Color.semantic.warning)
            Text(message)
                .font(.system(size: 10))
                .foregroundColor(DesignTokens.Color.semantic.warning)
                .lineLimit(2)
        }
        .padding(8)
        .background(DesignTokens.Color.adaptive.errorBackground(for: .dark))
        .cornerRadius(6)
    }
}


