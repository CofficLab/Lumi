import SwiftUI

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
                                } else {
                                    manager.popularExtensions = []
                                    manager.loadPopularExtensions(category: category)
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 2)
            }

            // 搜索结果 / 热门扩展
            if manager.isSearching {
                SearchLoadingView()
            } else if let error = manager.searchError {
                SearchErrorView(message: error)
            } else if manager.searchResults.isEmpty && !localSearchQuery.isEmpty {
                SearchEmptyView()
            } else if !manager.searchResults.isEmpty {
                SearchResultsList(results: manager.searchResults)
            } else if manager.isLoadingPopular {
                PopularLoadingView()
            } else if let error = manager.popularError {
                SearchErrorView(message: error)
            } else if !manager.popularExtensions.isEmpty {
                PopularExtensionsList(results: manager.popularExtensions)
            } else {
                SearchPlaceholderView()
                    .onAppear {
                        manager.loadPopularExtensions()
                    }
            }
        }
        .frame(maxHeight: .infinity)
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

// MARK: - Popular Loading View

struct PopularLoadingView: View {
    var body: some View {
        VStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text("正在加载热门扩展...")
                .font(.system(size: 12))
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
}

// MARK: - Popular Extensions List

struct PopularExtensionsList: View {
    let results: [OpenVSXExtension]

    var body: some View {
        ExtensionsList(results: results)
    }
}

// MARK: - Search Results List

struct SearchResultsList: View {
    let results: [OpenVSXExtension]

    var body: some View {
        ExtensionsList(results: results)
    }
}

// MARK: - Extensions List (shared)

struct ExtensionsList: View {
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
                let isIconTheme = ext.id.lowercased().contains("icon-theme") || ext.id.lowercased().contains("icons")
                if isIconTheme {
                    // 已安装的图标主题，显示「应用」按钮
                    Button(action: {
                        manager.applyIconTheme(ext.id)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 10))
                            Text("应用")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.blue)
                    .background(Color.blue.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
                    .help("应用此图标主题")
                } else {
                    Label("已安装", systemImage: "checkmark")
                        .font(.system(size: 10))
                        .foregroundColor(DesignTokens.Color.semantic.success)
                }
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
