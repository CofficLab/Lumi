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
    @State private var newExtensionId = ""
    @State private var isInstalling = false

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
                    InstalledExtensionsView(
                        newExtensionId: $newExtensionId,
                        isInstalling: $isInstalling
                    )
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
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(isSelected ? Color.gray.opacity(0.2) : Color.clear)
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
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

// MARK: - Market Search View

/// 市场搜索视图
struct MarketSearchView: View {
    @StateObject private var manager = CodeServerManager.shared
    @State private var localSearchQuery = ""
    @State private var debounceTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            // 搜索栏
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundColor(DesignTokens.Color.semantic.textTertiary)

                TextField("搜索扩展 (如: python, theme)", text: $localSearchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))

                if manager.isSearching {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 16, height: 16)
                } else if !localSearchQuery.isEmpty {
                    Button(action: {
                        localSearchQuery = ""
                        manager.searchResults = []
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(6)
            .onChange(of: localSearchQuery) { _, newValue in
                debounceTask?.cancel()
                debounceTask = Task {
                    try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
                    if !Task.isCancelled {
                        await MainActor.run {
                            manager.searchQuery = newValue
                            manager.searchMarket(query: newValue, category: manager.selectedCategory)
                        }
                    }
                }
            }

            // 分类选择
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(ExtensionCategory.allCases, id: \.self) { category in
                        CategoryButton(
                            title: category.displayName,
                            isSelected: manager.selectedCategory == category,
                            action: {
                                manager.selectedCategory = category
                                if !localSearchQuery.isEmpty {
                                    manager.searchMarket(query: localSearchQuery, category: category)
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 2)
            }

            // 搜索结果
            if manager.isSearching {
                SearchLoadingView()
            } else if let error = manager.searchError {
                SearchErrorView(message: error)
            } else if manager.searchResults.isEmpty && !localSearchQuery.isEmpty {
                SearchEmptyView()
            } else if !manager.searchResults.isEmpty {
                SearchResultsList(results: manager.searchResults)
            } else {
                SearchPlaceholderView()
            }
        }
    }
}

// MARK: - Category Button

struct CategoryButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10))
                .foregroundColor(isSelected ? .white : DesignTokens.Color.semantic.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(isSelected ? DesignTokens.Color.semantic.primary : Color.gray.opacity(0.1))
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Search Loading View

struct SearchLoadingView: View {
    var body: some View {
        VStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text("搜索中...")
                .font(.system(size: 12))
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
}

// MARK: - Search Error View

struct SearchErrorView: View {
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 24))
                .foregroundColor(DesignTokens.Color.semantic.warning)

            Text("搜索失败")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(DesignTokens.Color.semantic.textPrimary)

            Text(message)
                .font(.system(size: 11))
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
}

// MARK: - Search Empty View

struct SearchEmptyView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 24))
                .foregroundColor(DesignTokens.Color.semantic.textDisabled)

            Text("未找到相关扩展")
                .font(.system(size: 12))
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
}

// MARK: - Search Placeholder View

struct SearchPlaceholderView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 32))
                .foregroundColor(DesignTokens.Color.semantic.textDisabled)

            Text("Open VSX 扩展市场")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(DesignTokens.Color.semantic.textPrimary)

            Text("搜索并安装来自 Open VSX 的扩展\n支持数千个开源扩展")
                .font(.system(size: 11))
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                .multilineTextAlignment(.center)

            Link(destination: URL(string: "https://open-vsx.org")!) {
                HStack(spacing: 4) {
                    Image(systemName: "globe")
                        .font(.system(size: 10))
                    Text("访问 Open VSX 官网")
                        .font(.system(size: 11))
                }
                .foregroundColor(DesignTokens.Color.semantic.primary)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
}

// MARK: - Search Results List

struct SearchResultsList: View {
    let results: [OpenVSXExtension]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(results) { ext in
                    MarketExtensionRowView(ext: ext)
                        .padding(.vertical, 6)
                    
                    if ext.id != results.last?.id {
                        Divider()
                            .padding(.leading, 44)
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
    }
}

// MARK: - Market Extension Row View

struct MarketExtensionRowView: View {
    let ext: OpenVSXExtension
    @StateObject private var manager = CodeServerManager.shared
    @State private var isInstalling = false

    var body: some View {
        HStack(spacing: 10) {
            // 图标
            AsyncImage(url: ext.iconUrl.flatMap { URL(string: $0) }) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.1))
                    .overlay(
                        Image(systemName: "puzzlepiece.extension")
                            .font(.system(size: 14))
                            .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                    )
            }
            .frame(width: 32, height: 32)
            .cornerRadius(4)

            // 信息
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(ext.displayName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                        .lineLimit(1)

                    Text(ext.version)
                        .font(.system(size: 9))
                        .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(2)
                }

                if let description = ext.description, !description.isEmpty {
                    Text(description)
                        .font(.system(size: 10))
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                        .lineLimit(2)
                }

                // 下载量和评分
                HStack(spacing: 8) {
                    if !ext.formattedDownloads.isEmpty {
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.down.circle")
                                .font(.system(size: 8))
                            Text(ext.formattedDownloads)
                                .font(.system(size: 9))
                        }
                        .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                    }

                    if !ext.ratingStars.isEmpty {
                        HStack(spacing: 2) {
                            Text(ext.ratingStars)
                                .font(.system(size: 9))
                            Text(String(format: "%.1f", ext.averageRating ?? 0))
                                .font(.system(size: 9))
                        }
                        .foregroundColor(DesignTokens.Color.semantic.warning)
                    }

                    Text(ext.publisher ?? "")
                        .font(.system(size: 9))
                        .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                }
            }

            Spacer()

            // 安装/已安装按钮
            if manager.isExtensionInstalled(ext.id) {
                Label("已安装", systemImage: "checkmark")
                    .font(.system(size: 10))
                    .foregroundColor(DesignTokens.Color.semantic.success)
            } else {
                Button(action: {
                    install()
                }) {
                    if isInstalling {
                        ProgressView()
                            .scaleEffect(0.5)
                            .frame(width: 20, height: 20)
                    } else {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .semibold))
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(isInstalling)
            }
        }
        .padding(.horizontal, 4)
    }

    private func install() {
        isInstalling = true

        Task {
            _ = await manager.installExtension(ext.id)
            await MainActor.run {
                isInstalling = false
            }
        }
    }
}

// MARK: - Installed Extensions View

struct InstalledExtensionsView: View {
    @StateObject private var manager = CodeServerManager.shared
    @Binding var newExtensionId: String
    @Binding var isInstalling: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            // 扩展列表
            if manager.isLoadingExtensions {
                VStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("加载扩展列表...")
                        .font(.system(size: 12))
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                }
                .frame(maxWidth: .infinity, minHeight: 150)
            } else if manager.installedExtensions.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "puzzlepiece.extension")
                        .font(.system(size: 24))
                        .foregroundColor(DesignTokens.Color.semantic.textDisabled)

                    Text("未安装任何扩展")
                        .font(.system(size: 12))
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)

                    Text("点击上方「市场」标签搜索安装扩展")
                        .font(.system(size: 11))
                        .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                }
                .frame(maxWidth: .infinity, minHeight: 150)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(manager.installedExtensions) { ext in
                            ExtensionRowView(ext: ext)
                                .padding(.vertical, 6)
                        }
                    }
                }
                .frame(maxHeight: .infinity)
            }

            Divider()

            // 安装新扩展
            HStack(spacing: 8) {
                TextField("输入扩展 ID (如: ms-python.python)", text: $newExtensionId)
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
