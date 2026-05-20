import LumiUI
import SwiftUI

// MARK: - Market Search View

/// 市场搜索视图
struct MarketSearchView: View {
    @StateObject private var manager = CodeServerManager.shared
    @State private var localSearchQuery = ""
    @State private var debounceTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            searchBar

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

    private var searchBar: some View {
        HStack(spacing: 8) {
            AppSearchBar(
                text: $localSearchQuery,
                placeholder: LocalizedStringKey(String(localized: "搜索扩展 (如: python, theme)", table: "CodeServer"))
            )

            if manager.isSearching {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 20, height: 20)
            }
        }
        .onChange(of: localSearchQuery) { _, newValue in
            if newValue.isEmpty {
                manager.searchResults = []
            }

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
    }
}

// MARK: - Category Button

struct CategoryButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        AppButton(
            title,
            style: isSelected ? .primary : .tonal,
            size: .small,
            action: action
        )
    }
}

// MARK: - Search Loading View

struct SearchLoadingView: View {
    var body: some View {
        AppLoadingOverlay(
            message: LocalizedStringKey(String(localized: "搜索中...", table: "CodeServer")),
            size: .small
        )
            .frame(maxWidth: .infinity, minHeight: 200)
    }
}

// MARK: - Search Error View

struct SearchErrorView: View {
    let message: String

    var body: some View {
        VStack {
            AppErrorBanner(message: LocalizedStringKey(message))
                .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
}

// MARK: - Search Empty View

struct SearchEmptyView: View {
    var body: some View {
        AppEmptyState(
            icon: "magnifyingglass",
            title: LocalizedStringKey(String(localized: "未找到相关扩展", table: "CodeServer"))
        )
        .frame(maxWidth: .infinity, minHeight: 200)
    }
}

// MARK: - Search Placeholder View

struct SearchPlaceholderView: View {
    var body: some View {
        VStack(spacing: 12) {
            AppEmptyState(
                icon: "square.grid.2x2",
                title: LocalizedStringKey(String(localized: "Open VSX 扩展市场", table: "CodeServer")),
                description: LocalizedStringKey(String(localized: "搜索并安装来自 Open VSX 的扩展\n支持数千个开源扩展", table: "CodeServer"))
            )
            .frame(height: 150)

            Link(destination: URL(string: "https://open-vsx.org")!) {
                HStack(spacing: 4) {
                    Image(systemName: "globe")
                        .font(.system(size: 10))
                    Text(String(localized: "访问 Open VSX 官网", table: "CodeServer"))
                        .font(.system(size: 11))
                }
                .foregroundColor(Color(hex: "7C6FFF"))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
}

// MARK: - Popular Loading View

struct PopularLoadingView: View {
    var body: some View {
        AppLoadingOverlay(
            message: LocalizedStringKey(String(localized: "正在加载热门扩展...", table: "CodeServer")),
            size: .small
        )
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
        AppListRow {
            HStack(spacing: 10) {
                extensionIcon
                extensionInfo
                Spacer()
                installControl
            }
        }
        .padding(.horizontal, 4)
    }

    private var extensionIcon: some View {
        AsyncImage(url: ext.iconUrl.flatMap { URL(string: $0) }) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fit)
        } placeholder: {
            Image(systemName: "puzzlepiece.extension")
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "98989E"))
                .frame(width: 32, height: 32)
                .appSurface(style: .subtle, cornerRadius: 4)
        }
        .frame(width: 32, height: 32)
        .appClipRounded(4)
    }

    private var extensionInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(ext.displayName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
                    .lineLimit(1)

                AppTag(ext.version)
            }

            if let description = ext.description, !description.isEmpty {
                Text(description)
                    .font(.system(size: 10))
                    .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                    .lineLimit(2)
            }

            metadataRow
        }
    }

    private var metadataRow: some View {
        HStack(spacing: 8) {
            if !ext.formattedDownloads.isEmpty {
                Label(ext.formattedDownloads, systemImage: "arrow.down.circle")
            }

            if !ext.ratingStars.isEmpty {
                Text("\(ext.ratingStars) \(String(format: "%.1f", ext.averageRating ?? 0))")
                    .foregroundColor(Color(hex: "FF9F0A"))
            }

            Text(ext.publisher ?? "")
        }
        .font(.system(size: 9))
        .foregroundColor(Color(hex: "98989E"))
    }

    @ViewBuilder
    private var installControl: some View {
        if manager.isExtensionInstalled(ext.id) {
            let isIconTheme = ext.id.lowercased().contains("icon-theme") || ext.id.lowercased().contains("icons")
            if isIconTheme {
                AppButton(
                    String(localized: "应用", table: "CodeServer"),
                    systemImage: "checkmark.circle",
                    style: .tonal,
                    size: .small
                ) {
                    manager.applyIconTheme(ext.id)
                }
                .help(String(localized: "应用此图标主题", table: "CodeServer"))
            } else {
                AppTag(
                    String(localized: "已安装", table: "CodeServer"),
                    systemImage: "checkmark",
                    style: .accent
                )
            }
        } else if isInstalling {
            ProgressView()
                .controlSize(.small)
                .frame(width: 28, height: 28)
        } else {
            AppIconButton(systemImage: "plus", tint: .white, size: .compact) {
                install()
            }
        }
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
