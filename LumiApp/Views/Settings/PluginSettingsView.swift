import SwiftUI
import LumiUI
import AgentToolKit

/// 插件管理视图：VS Code 风格 - 左侧插件列表 + 右侧详情面板
struct PluginSettingsView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    /// 插件设置存储
    private let settingsStore = AppPluginSettingsVM.shared

    /// 插件 VM
    @EnvironmentObject var pluginProvider: AppPluginVM

    /// 当前选中的分类，nil 表示"全部"
    @State private var selectedCategory: PluginCategory?

    /// 插件启用状态
    @State private var pluginStates: [String: Bool] = [:]

    /// 当前选中的插件 ID
    @State private var selectedPluginId: String?

    /// 搜索关键词
    @State private var searchText = ""

    /// 左侧列表宽度
    private let sidebarWidth: CGFloat = 280

    // MARK: - Localized strings

    private var locSearchPlaceholder: String {
        String(localized: "搜索插件", table: "Localizable")
    }
    private var locAll: String {
        String(localized: "全部", table: "Localizable")
    }
    private var locNoPlugins: String {
        String(localized: "该分类下暂无可配置的插件", table: "Localizable")
    }
    private var locSelectPrompt: String {
        String(localized: "请选择一个插件查看详情", table: "Localizable")
    }
    private var locConfigurable: String {
        String(localized: "可配置", table: "Localizable")
    }
    private var locEnabled: String {
        String(localized: "已启用", table: "Localizable")
    }
    private var locEnable: String {
        String(localized: "启用", table: "Localizable")
    }
    private var locCurrentlyEnabled: String {
        String(localized: "当前已启用", table: "Localizable")
    }
    private var locCanBeEnabled: String {
        String(localized: "可按需启用", table: "Localizable")
    }
    private var locRunning: String {
        String(localized: "该插件正在运行", table: "Localizable")
    }
    private var locDefaultPosterDesc: String {
        String(localized: "为 Lumi 增加一项可配置能力", table: "Localizable")
    }

    var body: some View {
        HStack(spacing: 0) {
            // 左侧插件列表
            pluginListView
                .frame(width: sidebarWidth)
                .background(.background.opacity(0.6))

            Divider()

            // 右侧详情面板
            pluginDetailView
        }
        .onAppear {
            loadPluginStates()
            if !filteredPlugins.isEmpty, let firstId = filteredPlugins.first?.instanceLabel {
                selectedPluginId = firstId
            }
        }
        .onChange(of: searchText) { _, _ in
            syncSelectionAfterFilter()
        }
        .onChange(of: selectedCategory) { _, _ in
            syncSelectionAfterFilter()
        }
    }

    // MARK: - Sidebar (Plugin List)

    private var pluginListView: some View {
        VStack(spacing: 0) {
            // 分类 Tab 栏
            categoryTabs
                .padding(.horizontal, 14)
                .padding(.top, 16)
                .padding(.bottom, 10)

            // 搜索栏
            searchBar
                .padding(.horizontal, 14)
                .padding(.bottom, 8)

            // 插件列表
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(filteredPlugins, id: \.instanceLabel) { plugin in
                        pluginListItem(plugin)
                    }

                    if filteredPlugins.isEmpty {
                        emptyStateView
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
            }

            // 底部统计
            statsBar
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "puzzlepiece.extension")
                .font(.appTitle)
                .foregroundColor(theme.textTertiary)

            Text(locNoPlugins)
                .font(.appCaption)
                .foregroundColor(theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Category Tabs

    private var categoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                categoryTab(title: locAll, isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }

                ForEach(availableCategories, id: \.self) { category in
                    categoryTab(
                        title: category.displayName,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                    }
                }
            }
        }
    }

    private func categoryTab(
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.appCaption)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .foregroundColor(isSelected ? theme.textPrimary : theme.textTertiary)
                .background(
                    Capsule()
                        .fill(isSelected ? theme.appAccentSoftFill : Color.clear)
                )
                .overlay(
                    Capsule()
                        .strokeBorder(
                            isSelected ? theme.primary.opacity(0.3) : theme.appDivider,
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.appCaption)
                .foregroundColor(theme.textTertiary)

            TextField(locSearchPlaceholder, text: $searchText)
                .font(.appCaption)
                .textFieldStyle(.plain)
                .foregroundColor(theme.textPrimary)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.appCaption)
                        .foregroundColor(theme.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(theme.appPanelBackground.opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(theme.appDivider, lineWidth: 1)
        )
    }

    // MARK: - Plugin List Item

    private func pluginListItem(_ plugin: any SuperPlugin) -> some View {
        let pluginId = plugin.instanceLabel
        let isEnabled = pluginStates[pluginId, default: true]
        let isSelected = selectedPluginId == pluginId

        return Button {
            selectedPluginId = pluginId
        } label: {
            HStack(spacing: 10) {
                Image(systemName: plugin.pluginIconName)
                    .font(.appBody)
                    .foregroundColor(isEnabled ? theme.primary : theme.textTertiary)
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(plugin.pluginDisplayName)
                        .font(.appCaption)
                        .foregroundColor(isSelected ? theme.textPrimary : theme.textSecondary)
                        .lineLimit(1)

                    Text(plugin.pluginDescription(for: .current))
                        .font(.appMicro)
                        .foregroundColor(theme.textTertiary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Circle()
                    .fill(isEnabled ? theme.primary : theme.appDivider)
                    .frame(width: 8, height: 8)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .appSurface(
            style: .custom(isSelected ? Color.secondary.opacity(0.25) : Color.clear),
            cornerRadius: 6
        )
    }

    // MARK: - Detail View

    private var pluginDetailView: some View {
        Group {
            if let selectedPluginId,
               let plugin = pluginProvider.plugins.first(where: {
                   $0.instanceLabel == selectedPluginId && $0.pluginIsConfigurable
               }) {
                pluginDetailContent(plugin)
            } else if filteredPlugins.isEmpty {
                Text(locNoPlugins)
                    .font(.appCaption)
                    .foregroundColor(theme.textTertiary)
            } else {
                Text(locSelectPrompt)
                    .font(.appCaption)
                    .foregroundColor(theme.textTertiary)
            }
        }
    }

    private func pluginDetailContent(_ plugin: any SuperPlugin) -> some View {
        let pluginId = plugin.instanceLabel
        let isEnabled = pluginStates[pluginId, default: true]

        return VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    posterSection(plugin, isEnabled: isEnabled)
                        .padding(.top, 24)

                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .top, spacing: 16) {
                            Image(systemName: plugin.pluginIconName)
                                .font(.system(size: 40, weight: .semibold))
                                .foregroundColor(theme.primary)
                                .frame(width: 72, height: 72)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(theme.appAccentSoftFill)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(theme.appDivider, lineWidth: 1)
                                )

                            VStack(alignment: .leading, spacing: 8) {
                                Text(plugin.pluginDisplayName)
                                    .font(.appTitle)
                                    .fontWeight(.semibold)
                                    .foregroundColor(theme.textPrimary)

                                Text(plugin.pluginDescription(for: .current))
                                    .font(.appCaption)
                                    .foregroundColor(theme.textSecondary)
                                    .lineLimit(3)

                                HStack(spacing: 6) {
                                    Image(systemName: plugin.pluginCategory.systemImage)
                                        .font(.appMicro)
                                    Text(plugin.pluginCategory.displayName)
                                        .font(.appMicro)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(theme.appStatusMutedFill))
                                .foregroundColor(theme.textSecondary)
                            }

                            Spacer(minLength: 0)
                        }

                        HStack(spacing: 12) {
                            Button {
                                pluginStates[pluginId] = !isEnabled
                                settingsStore.setPluginEnabled(pluginId, enabled: !isEnabled)
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                                    Text(isEnabled ? locEnabled : locEnable)
                                        .fontWeight(.semibold)
                                }
                                .font(.appBody)
                                .foregroundColor(isEnabled ? theme.textSecondary : theme.primary)
                                .frame(minWidth: 100)
                                .padding(.vertical, 10)
                                .background(
                                    Capsule()
                                        .fill(isEnabled ? theme.appStatusMutedFill : theme.appAccentSoftFill)
                                )
                            }
                            .buttonStyle(.plain)

                            if isEnabled {
                                Text(locRunning)
                                    .font(.appCaption)
                                    .foregroundColor(theme.textTertiary)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)

                    Spacer(minLength: 60)
                }
                .padding(.bottom, 16)
            }
        }
        .mystiqueBackground()
        .ignoresSafeArea()
    }

    // MARK: - Poster Section

    private func posterSection(_ plugin: any SuperPlugin, isEnabled: Bool) -> some View {
        let posterViews = plugin.addPosterViews()

        return Group {
            if posterViews.isEmpty {
                defaultPoster(plugin, isEnabled: isEnabled)
                    .frame(maxWidth: .infinity)
                    .frame(height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(theme.appDivider, lineWidth: 1)
                    )
            } else if posterViews.count == 1, let posterView = posterViews.first {
                posterView
                    .frame(maxWidth: .infinity)
                    .frame(height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(theme.appDivider, lineWidth: 1)
                    )
            } else {
                posterCarousel(posterViews)
            }
        }
        .padding(.horizontal, 24)
    }

    private func defaultPoster(_ plugin: any SuperPlugin, isEnabled: Bool) -> some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [
                    theme.primary.opacity(0.16),
                    theme.primarySecondary.opacity(0.08),
                    theme.appPanelBackground
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            HStack(alignment: .top, spacing: 20) {
                Image(systemName: plugin.pluginIconName)
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundColor(theme.primary)
                    .frame(width: 84, height: 84)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(theme.appAccentSoftFill)
                    )

                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(plugin.pluginDisplayName)
                            .font(.appTitle)
                            .fontWeight(.semibold)
                            .foregroundColor(theme.textPrimary)
                            .lineLimit(1)

                        Text(plugin.pluginDescription(for: .current).isEmpty
                             ? locDefaultPosterDesc
                             : plugin.pluginDescription(for: .current))
                            .font(.appCaption)
                            .foregroundColor(theme.textSecondary)
                            .lineLimit(2)
                    }

                    HStack(spacing: 8) {
                        featurePill(locConfigurable)
                        featurePill(isEnabled ? locCurrentlyEnabled : locCanBeEnabled)
                    }

                    Spacer(minLength: 0)
                }

                Spacer(minLength: 0)
            }
            .padding(24)
        }
    }

    @State private var posterIndex = 0

    private func posterCarousel(_ views: [AnyView]) -> some View {
        ZStack(alignment: .bottom) {
            posterCarouselFrame(views[normalizedPosterIndex])

            HStack(spacing: 8) {
                carouselButton(systemImage: "chevron.left") {
                    posterIndex = (normalizedPosterIndex - 1 + views.count) % views.count
                }

                HStack(spacing: 5) {
                    ForEach(views.indices, id: \.self) { index in
                        Circle()
                            .fill(index == normalizedPosterIndex ? theme.primary : theme.textTertiary.opacity(0.35))
                            .frame(width: 6, height: 6)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 7)
                .background(Capsule().fill(theme.appPanelBackground.opacity(0.82)))

                carouselButton(systemImage: "chevron.right") {
                    posterIndex = (normalizedPosterIndex + 1) % views.count
                }
            }
            .padding(.bottom, 22)
        }
    }

    private func posterCarouselFrame(_ posterView: AnyView) -> some View {
        posterView
            .frame(maxWidth: .infinity)
            .frame(height: 240)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var normalizedPosterIndex: Int {
        max(0, posterIndex)
    }

    private func carouselButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.appCaptionEmphasized)
                .foregroundColor(theme.textPrimary)
                .frame(width: 28, height: 28)
                .background(Circle().fill(theme.appPanelBackground.opacity(0.82)))
        }
        .buttonStyle(.plain)
    }

    private func featurePill(_ title: String) -> some View {
        Text(title)
            .font(.appMicroEmphasized)
            .foregroundColor(theme.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(theme.appStatusMutedFill))
    }

    // MARK: - Stats Bar

    private var statsBar: some View {
        HStack {
            Spacer()

            Text(String(localized: "共 \(filteredPlugins.count) 个插件 · \(enabledCount) 个已启用", table: "Localizable"))
                .font(.appMicro)
                .foregroundColor(theme.textTertiary)

            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 14)
        .background(.bar)
    }

    // MARK: - Data

    private var availableCategories: [PluginCategory] {
        groupedPlugins.map(\.category)
    }

    private var groupedPlugins: [(category: PluginCategory, plugins: [any SuperPlugin])] {
        pluginProvider.getConfigurablePluginsGroupedByCategory()
    }

    private var filteredPlugins: [any SuperPlugin] {
        var plugins: [any SuperPlugin]
        if let selectedCategory {
            plugins = groupedPlugins
                .first(where: { $0.category == selectedCategory })?
                .plugins ?? []
        } else {
            plugins = groupedPlugins.flatMap(\.plugins)
        }

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            plugins = plugins.filter {
                $0.pluginDisplayName.lowercased().contains(query)
                    || $0.pluginDescription(for: .current).lowercased().contains(query)
            }
        }

        return plugins
    }

    private var enabledCount: Int {
        filteredPlugins.filter { pluginStates[$0.instanceLabel, default: true] }.count
    }

    private func loadPluginStates() {
        var states: [String: Bool] = [:]
        for plugin in pluginProvider.plugins.filter(\.pluginIsConfigurable) {
            states[plugin.instanceLabel] = settingsStore.isPluginEnabled(
                plugin.instanceLabel,
                defaultEnabled: plugin.pluginEnabledByDefault
            )
        }
        pluginStates = states
    }

    /// 同步选中状态：当搜索或分类变化导致当前选中项不可见时，自动重置
    private func syncSelectionAfterFilter() {
        if let currentId = selectedPluginId,
           filteredPlugins.contains(where: { $0.instanceLabel == currentId }) {
            // 当前选中项仍在列表中，无需重置
            return
        }
        // 当前选中项被过滤掉了，选中第一个可见项或清空
        selectedPluginId = filteredPlugins.first?.instanceLabel
    }
}

// MARK: - Preview

#Preview("Plugin Settings") {
    PluginSettingsView()
        .frame(width: 700, height: 500)
        .inRootView()
}
