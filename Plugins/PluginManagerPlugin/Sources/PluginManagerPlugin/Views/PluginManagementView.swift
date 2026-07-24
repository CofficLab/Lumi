import LocalizationKit
import LumiKernel
import LumiUI
import SwiftUI

/// 插件管理设置页。
///
/// 两栏布局:左侧为插件列表(搜索 + 分类筛选),右侧为选中插件的详情
/// 与启用开关。对齐旧版本 4.19.0 的体验。通过 `@ObservedObject kernel`
/// 驱动刷新——`setPlugin` 会触发 `objectWillChange` 与 `.lumiEnabledPluginsDidChange`,
/// 使列表/详情/全局 UI 贡献即时更新。
struct PluginManagementView: View {
    @LumiTheme private var theme
    @ObservedObject var kernel: LumiKernel

    @State private var selectedPluginID: String?
    @State private var searchText = ""
    @State private var selectedCategory: LumiPluginCategory?

    /// 列表数据源:仅显示用户可配置的插件(对齐 4.19.0 的行为)。
    /// `alwaysOn`(不可禁用)与 `disabled`(不可启用)都不可配置,
    /// 展示在管理列表中没有可操作控件,故一并过滤掉,只保留 `optOut` / `optIn`。
    private var plugins: [LumiPlugin] {
        kernel.pluginManager.allPlugins.filter { $0.policy.isConfigurable }
    }

    /// 列表上出现的分类(按 sortOrder 排序),用于筛选标签栏。
    private var availableCategories: [LumiPluginCategory] {
        let present = Set(plugins.map(\.category))
        return LumiPluginCategory.allCases
            .filter { present.contains($0) }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    private var filteredPlugins: [LumiPlugin] {
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return plugins.filter { plugin in
            let matchesCategory = selectedCategory.map { plugin.category == $0 } ?? true
            let matchesKeyword = keyword.isEmpty
                || plugin.name.localizedCaseInsensitiveContains(keyword)
                || plugin.id.localizedCaseInsensitiveContains(keyword)
                || plugin.pluginDescription.localizedCaseInsensitiveContains(keyword)
            return matchesCategory && matchesKeyword
        }
    }

    private var selectedPlugin: LumiPlugin? {
        if let selectedPluginID,
           let plugin = plugins.first(where: { $0.id == selectedPluginID }) {
            return plugin
        }
        return filteredPlugins.first ?? plugins.first
    }

    var body: some View {
        AppSettingsContentScaffold(scrollsContent: false, maxContentWidth: nil) {
            VStack(alignment: .leading, spacing: 14) {
                headerStats

                HStack(spacing: 0) {
                    pluginListPane
                        .frame(width: 300)
                        .frame(maxHeight: .infinity)

                    AppDivider(.vertical)

                    pluginDetailPane
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                .frame(minHeight: 520, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(theme.divider, lineWidth: 1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .onAppear {
            if selectedPluginID == nil {
                selectedPluginID = selectedPlugin?.id
            }
        }
        .onChange(of: filteredPlugins.map(\.id)) { _, ids in
            guard let selectedPluginID,
                  ids.contains(selectedPluginID)
            else {
                self.selectedPluginID = ids.first
                return
            }
        }
    }

    /// 当前列表中处于有效启用状态的可配置插件数。
    /// 基于 `plugins`(已过滤 alwaysOn),与列表项数口径一致。
    private var enabledCount: Int {
        plugins.reduce(0) { $0 + (kernel.pluginManager.effectiveEnabled(for: $1) ? 1 : 0) }
    }

    private var headerStats: some View {
        HStack(spacing: 10) {
            Label(
                String(format: PluginManagerText.string(PluginManagerText.pluginsCount), plugins.count),
                systemImage: "puzzlepiece.extension"
            )
            Text(String(format: PluginManagerText.string(PluginManagerText.enabledCount), enabledCount))
            Spacer()
        }
        .font(.appCaption)
        .foregroundStyle(theme.textSecondary)
    }

    // MARK: - List Pane

    private var pluginListPane: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                AppSearchBar(
                    text: $searchText,
                    placeholder: LocalizedStringKey(PluginManagerText.string(PluginManagerText.searchPlugins))
                )

                // 分类筛选标签栏
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        categoryChip(title: PluginManagerText.string(PluginManagerText.allCategories), isSelected: selectedCategory == nil) {
                            selectedCategory = nil
                        }
                        ForEach(availableCategories, id: \.self) { category in
                            categoryChip(title: category.displayName, isSelected: selectedCategory == category) {
                                selectedCategory = category
                            }
                        }
                    }
                }
            }
            .padding(12)

            AppDivider()

            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(filteredPlugins, id: \.id) { plugin in
                        pluginListRow(plugin)
                    }

                    if filteredPlugins.isEmpty {
                        AppEmptyState(
                            icon: "magnifyingglass",
                            title: PluginManagerText.string(PluginManagerText.noPluginsFound)
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

    private func categoryChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
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

    private func pluginListRow(_ plugin: LumiPlugin) -> some View {
        let isSelected = selectedPluginID == plugin.id
        let isEnabled = kernel.pluginManager.effectiveEnabled(for: plugin)

        return AppListRow(isSelected: isSelected, action: { selectedPluginID = plugin.id }) {
            HStack(alignment: .top, spacing: 10) {
                VStack(spacing: 6) {
                    Image(systemName: plugin.category.systemImage)
                        .font(.appBody)
                        .foregroundStyle(isSelected ? theme.primary : theme.textSecondary)
                        .frame(width: 22, height: 22)

                    Circle()
                        .fill(isEnabled ? theme.success : theme.textTertiary.opacity(0.5))
                        .frame(width: 6, height: 6)
                }
                .frame(width: 22)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(plugin.name)
                            .font(.appCaptionEmphasized)
                            .foregroundStyle(theme.textPrimary)
                            .lineLimit(1)

                        if plugin.stage != .stable {
                            AppTag(plugin.stage.displayName, style: .subtle)
                        }
                    }

                    Text(plugin.pluginDescription.isEmpty ? plugin.id : plugin.pluginDescription)
                        .font(.appMicro)
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Detail Pane

    @ViewBuilder
    private var pluginDetailPane: some View {
        if let selectedPlugin {
            PluginSettingsDetailView(kernel: kernel, plugin: selectedPlugin)
        } else {
            AppEmptyState(
                icon: "puzzlepiece.extension",
                title: PluginManagerText.string(PluginManagerText.selectPlugin)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Detail

private struct PluginSettingsDetailView: View {
    @LumiTheme private var theme
    let kernel: LumiKernel
    let plugin: LumiPlugin

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                AppDivider()
                metaInfo
                AppDivider()
                pluginSettingsContent
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appSurface(style: .panel, cornerRadius: 0)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: plugin.category.systemImage)
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(theme.primary)
                .frame(width: 64, height: 64)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(theme.appAccentSoftFill)
                )

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    Text(plugin.name)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(theme.textPrimary)

                    AppTag(plugin.stage.displayName, style: plugin.stage == .stable ? .accent : .subtle)
                }

                Text(plugin.id)
                    .font(.appCaption)
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if !plugin.pluginDescription.isEmpty {
                    Text(plugin.pluginDescription)
                        .font(.appCaption)
                        .foregroundStyle(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // 启用/关闭开关置于右上角
            enableControl
                .fixedSize()
        }
    }

    @ViewBuilder
    private var enableControl: some View {
        let isEnabled = kernel.pluginManager.effectiveEnabled(for: plugin)
        if plugin.policy.isConfigurable {
            Toggle(isOn: Binding(
                get: { isEnabled },
                set: { newValue in kernel.pluginManager.setPlugin(id: plugin.id, enabled: newValue) }
            )) {
                Text(PluginManagerText.string(PluginManagerText.enable))
                    .font(.appBody)
                    .foregroundStyle(theme.textPrimary)
            }
            .toggleStyle(.switch)
        } else {
            switch plugin.policy {
            case .alwaysOn:
                AppTag(PluginManagerText.string(PluginManagerText.alwaysOn), systemImage: "lock.fill", style: .accent)
            case .disabled:
                AppTag(PluginManagerText.string(PluginManagerText.disabled), systemImage: "minus.circle")
            default:
                EmptyView()
            }
        }
    }

    private var metaInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            metaRow(label: PluginManagerText.string("Category"), value: plugin.category.displayName)
            metaRow(
                label: PluginManagerText.string("Policy"),
                value: policyDisplayName(plugin.policy)
            )
            metaRow(
                label: PluginManagerText.string("Order"),
                value: String(format: PluginManagerText.string(PluginManagerText.order), plugin.order)
            )
            metaRow(
                label: PluginManagerText.string("Stage"),
                value: "\(plugin.stage.displayName) · \(plugin.stage.description)"
            )
        }
        .font(.appCaption)
    }

    private func metaRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(theme.textTertiary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .foregroundStyle(theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func policyDisplayName(_ policy: LumiPluginPolicy) -> String {
        switch policy {
        case .alwaysOn: PluginManagerText.string(PluginManagerText.alwaysOn)
        case .disabled: PluginManagerText.string(PluginManagerText.disabled)
        case .optOut: "Opt-Out"
        case .optIn: "Opt-In"
        }
    }

    @ViewBuilder
    private var pluginSettingsContent: some View {
        if let about = plugin.pluginAboutView(kernel: kernel) {
            about
        } else {
            AppEmptyState(
                icon: "info.circle",
                title: PluginManagerText.string(PluginManagerText.noDetailsProvided),
                description: PluginManagerText.string(PluginManagerText.noDetailsHint)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
