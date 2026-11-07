import LumiUI
import SwiftUI

/// 插件管理设置页。
///
/// View 只依赖 `PluginManagementViewModel`；插件列表、筛选、选中项、详情和启停
/// 状态均由 VM 提供，外部插件事件由 `PluginManagementObserver` 写回 VM。
///
/// 布局按宽度分两态：
/// - 常规宽度：左侧列表 + 右侧详情的分栏布局（macOS 与 iPad）。
/// - 紧凑宽度（iPhone）：改为列表 + `NavigationLink` 推入详情，避免分栏在
///   窄屏下互相挤压。
struct PluginManagementView: View {
    @LumiTheme private var theme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @ObservedObject private var viewModel: PluginManagementViewModel

    init(viewModel: PluginManagementViewModel) {
        self.viewModel = viewModel
    }

    private var isCompact: Bool {
        horizontalSizeClass == .compact
    }

    var body: some View {
        Group {
            if isCompact {
                compactBody
            } else {
                regularBody
            }
        }
        .onAppear {
            viewModel.normalizeSelection()
        }
        .onChange(of: viewModel.filteredPlugins.map(\.id)) { _ in
            viewModel.normalizeSelection()
        }
    }

    // MARK: - 紧凑布局（iPhone）

    private var compactBody: some View {
        AppSettingsContentScaffold(maxContentWidth: nil) {
            VStack(alignment: .leading, spacing: 14) {
                toolbar
                errorBanner

                LazyVStack(spacing: 4) {
                    ForEach(viewModel.filteredPlugins) { plugin in
                        NavigationLink {
                            PluginSettingsDetailView(viewModel: viewModel)
                                .onAppear { viewModel.selectPlugin(id: plugin.id) }
                                .navigationTitle(plugin.metadata.name)
#if os(iOS)
                                .navigationBarTitleDisplayMode(.inline)
#endif
                        } label: {
                            PluginListRow(
                                plugin: plugin,
                                isSelected: viewModel.selectedPlugin?.id == plugin.id
                            ) {
                                viewModel.selectPlugin(id: plugin.id)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 9)
                        }
                        .buttonStyle(.plain)
                    }

                    if viewModel.filteredPlugins.isEmpty {
                        AppEmptyState(
                            icon: "magnifyingglass",
                            title: PluginPluginManagerText.noPluginsFound
                        )
                        .padding(.vertical, 32)
                        .accessibilityIdentifier("plugin-management.empty")
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - 分栏布局（macOS / iPad）

    private var regularBody: some View {
        AppSettingsContentScaffold(scrollsContent: false, maxContentWidth: nil) {
            GeometryReader { proxy in
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 10) {
                        PluginManagementHeader(
                            totalCount: viewModel.plugins.count,
                            enabledCount: viewModel.enabledCount
                        )
                        Spacer()
                        AppButton(
                            viewModel.isDisablingAll
                                ? PluginPluginManagerText.disablingAll
                                : PluginPluginManagerText.disableAll,
                            systemImage: "xmark.circle",
                            style: .secondary,
                            size: .small
                        ) {
                            viewModel.disableAllPlugins()
                        }
                        .disabled(viewModel.isDisablingAll || viewModel.enabledCount == 0)
                    }
                    .font(.appCaption)
                    .foregroundStyle(theme.textSecondary)
                    // 主体内容贴边后，用一条顶部分隔线把头部行与主从容器分开。
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)

                    errorBanner
                        .padding(.horizontal, 24)
                        .padding(.bottom, 12)

                    AppDivider()

                    HStack(spacing: 0) {
                        pluginListPane
                            .frame(width: 300)
                            .frame(maxHeight: .infinity)

                        AppDivider(.vertical)

                        PluginSettingsDetailView(viewModel: viewModel)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                    .frame(maxHeight: .infinity)
                }
                // 共享 scaffold 给内容留了左右 24，这里把整列加宽 48 并左移 24，
                // 使主从容器正好贴到窗口左右边缘；标题行再自行补回 24 留白。
                .frame(width: proxy.size.width + 48, alignment: .topLeading)
                .offset(x: -24)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        // 插件贡献的「关于 / 详情」内容里也可能出现 AppCard，统一按 .subtle 渲染，
        // 避免插件管理页里的卡片与其它设置页外观不一致。
        .environment(\.appSettingsCardStyleOverride, .subtle)
    }

    // MARK: - 头部与错误提示

    private var toolbar: some View {
        HStack(spacing: 10) {
            PluginManagementHeader(
                totalCount: viewModel.plugins.count,
                enabledCount: viewModel.enabledCount
            )
            Spacer()
            AppButton(
                viewModel.isDisablingAll
                    ? PluginPluginManagerText.disablingAll
                    : PluginPluginManagerText.disableAll,
                systemImage: "xmark.circle",
                style: .secondary,
                size: .small
            ) {
                viewModel.disableAllPlugins()
            }
            .disabled(viewModel.isDisablingAll || viewModel.enabledCount == 0)
        }
    }

    @ViewBuilder
    private var errorBanner: some View {
        if let errorMessage = viewModel.errorMessage {
            AppErrorBanner(
                message: LocalizedStringKey(errorMessage),
                retryTitle: "知道了"
            ) {
                viewModel.clearError()
            }
        }
    }

    // MARK: - 列表栏

    private var pluginListPane: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                // 插件数量少的时候不显示搜索框（列表一眼可见，搜索只是噪音）。
                if viewModel.showsSearchBar {
                    AppSearchBar(
                        text: $viewModel.searchText,
                        placeholder: LocalizedStringKey(PluginPluginManagerText.searchPlugins)
                    )
                }

                AppSegmentedControl(
                    PluginManagementFilter.allCases.map(\.title),
                    selection: Binding(
                        get: { PluginManagementFilter.allCases.firstIndex(of: viewModel.statusFilter) ?? 0 },
                        set: { viewModel.statusFilter = PluginManagementFilter.allCases[$0] }
                    ),
                    maxWidth: .infinity
                )

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        categoryChip(
                            title: PluginPluginManagerText.allCategories,
                            isSelected: viewModel.selectedCategory == nil
                        ) {
                            viewModel.selectedCategory = nil
                        }
                        ForEach(viewModel.availableCategories, id: \.self) { category in
                            categoryChip(
                                title: category.displayName,
                                isSelected: viewModel.selectedCategory == category
                            ) {
                                viewModel.selectedCategory = category
                            }
                        }
                    }
                }
            }
            .padding(12)

            AppDivider()

            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(viewModel.filteredPlugins) { plugin in
                        PluginListRow(
                            plugin: plugin,
                            isSelected: viewModel.selectedPlugin?.id == plugin.id
                        ) {
                            viewModel.selectPlugin(id: plugin.id)
                        }
                    }

                    if viewModel.filteredPlugins.isEmpty {
                        AppEmptyState(
                            icon: "magnifyingglass",
                            title: PluginPluginManagerText.noPluginsFound
                        )
                        .padding(.vertical, 32)
                    }
                }
                .padding(8)
            }
            .frame(maxHeight: .infinity)
        }
        .appSurface(style: .panel, cornerRadius: 0)
    }

    private func categoryChip(
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.appCaption)
                .foregroundStyle(isSelected ? theme.textPrimary : theme.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isSelected ? theme.primary.opacity(0.14) : theme.textSecondary.opacity(0.08))
                )
        }
        .buttonStyle(.plain)
    }
}
