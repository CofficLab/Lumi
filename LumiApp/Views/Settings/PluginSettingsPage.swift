import LumiCoreKit
import LumiUI
import SwiftUI

struct PluginSettingsPage: View {
    @LumiTheme private var theme
    @ObservedObject var pluginService: PluginService
    @State private var selectedCategory: LumiPluginCategory?
    @State private var selectedPluginID: String?
    @State private var searchText = ""

    private var pluginRows: [PluginSettingsRowModel] {
        pluginService.plugins
            .map { PluginSettingsRowModel(plugin: $0) }
            .sorted { lhs, rhs in
                if lhs.category.sortOrder != rhs.category.sortOrder {
                    return lhs.category.sortOrder < rhs.category.sortOrder
                }
                return lhs.order < rhs.order
            }
    }

    private var filteredRows: [PluginSettingsRowModel] {
        pluginRows.filter { row in
            let matchesCategory = selectedCategory == nil || row.category == selectedCategory
            let normalizedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let matchesSearch = normalizedSearch.isEmpty
                || row.displayName.localizedCaseInsensitiveContains(normalizedSearch)
                || row.description.localizedCaseInsensitiveContains(normalizedSearch)
                || row.id.localizedCaseInsensitiveContains(normalizedSearch)
            return matchesCategory && matchesSearch
        }
    }

    private var selectedRow: PluginSettingsRowModel? {
        if let selectedPluginID,
           let row = pluginRows.first(where: { $0.id == selectedPluginID }) {
            return row
        }

        return filteredRows.first ?? pluginRows.first
    }

    private var availableCategories: [LumiPluginCategory] {
        var categories: [LumiPluginCategory] = []
        for row in pluginRows where !categories.contains(row.category) {
            categories.append(row.category)
        }
        return categories.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var enabledCount: Int {
        pluginRows.filter { pluginService.isPluginEnabled($0.plugin) }.count
    }

    var body: some View {
        SettingsPageScaffold(
            title: "插件",
            subtitle: "管理插件启用状态和查看插件说明",
            maxContentWidth: nil,
            scrollsContent: false
        ) {
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
                selectedPluginID = selectedRow?.id
            }
        }
        .onChange(of: filteredRows.map(\.id)) { _, _ in
            guard let selectedPluginID,
                  filteredRows.contains(where: { $0.id == selectedPluginID })
            else {
                self.selectedPluginID = filteredRows.first?.id
                return
            }
        }
    }

    private var headerStats: some View {
        HStack(spacing: 10) {
            Label("\(pluginRows.count) 个插件", systemImage: "puzzlepiece.extension")
            Text("\(enabledCount) 个已启用")
            Spacer()
        }
        .font(.appCaption)
        .foregroundStyle(theme.textSecondary)
    }

    private var pluginListPane: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                AppSearchBar(text: $searchText, placeholder: "搜索插件")

                categoryTabs
            }
            .padding(12)

            AppDivider()

            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(filteredRows) { row in
                        pluginListRow(row)
                    }

                    if filteredRows.isEmpty {
                        AppEmptyState(icon: "magnifyingglass", title: "未找到插件")
                            .padding(.vertical, 32)
                    }
                }
                .padding(8)
            }
            .frame(maxHeight: .infinity)
        }
        .appSurface(style: .panel, cornerRadius: 0)
    }

    private var categoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                categoryTab("全部", systemImage: "square.grid.2x2", isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }

                ForEach(availableCategories, id: \.self) { category in
                    categoryTab(category.displayName, systemImage: category.systemImage, isSelected: selectedCategory == category) {
                        selectedCategory = category
                    }
                }
            }
        }
    }

    private func categoryTab(
        _ title: String,
        systemImage: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.appMicro)
                Text(title)
                    .font(.appMicro)
            }
            .foregroundColor(isSelected ? theme.textPrimary : theme.textSecondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(Capsule().fill(isSelected ? theme.appAccentSoftFill : Color.clear))
            .overlay {
                Capsule()
                    .strokeBorder(isSelected ? theme.primary.opacity(0.32) : theme.appDivider, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func pluginListRow(_ row: PluginSettingsRowModel) -> some View {
        let isSelected = selectedPluginID == row.id
        let isEnabled = pluginService.isPluginEnabled(row.plugin)

        return Button {
            selectedPluginID = row.id
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: row.iconName)
                    .font(.appBody)
                    .foregroundStyle(isSelected ? theme.primary : theme.textSecondary)
                    .frame(width: 22, height: 22)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(row.displayName)
                            .font(.appCaptionEmphasized)
                            .foregroundStyle(theme.textPrimary)
                            .lineLimit(1)

                        Circle()
                            .fill(isEnabled ? theme.success : theme.textTertiary.opacity(0.5))
                            .frame(width: 6, height: 6)
                    }

                    Text(row.description.isEmpty ? row.id : row.description)
                        .font(.appMicro)
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected ? theme.appAccentSoftFill : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var pluginDetailPane: some View {
        if let selectedRow {
            PluginSettingsDetailView(
                row: selectedRow,
                pluginService: pluginService
            )
        } else {
            AppEmptyState(icon: "puzzlepiece.extension", title: "选择一个插件")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct PluginSettingsDetailView: View {
    @LumiTheme private var theme
    let row: PluginSettingsRowModel
    @ObservedObject var pluginService: PluginService

    private var isEnabled: Bool {
        pluginService.isPluginEnabled(row.plugin)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                AppDivider()

                if let detail = row.plugin.settingsDetailView(context: settingsContext) {
                    detail
                } else {
                    defaultDetail
                }
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appSurface(style: .panel, cornerRadius: 0)
    }

    private var settingsContext: LumiPluginContext {
        LumiPluginContext(
            activeSectionID: "settings.plugins",
            activeSectionTitle: "插件管理"
        )
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: row.iconName)
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(theme.primary)
                .frame(width: 64, height: 64)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(theme.appAccentSoftFill)
                )

            VStack(alignment: .leading, spacing: 7) {
                Text(row.displayName)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(theme.textPrimary)

                Text(row.description.isEmpty ? row.id : row.description)
                    .font(.appCaption)
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    policyBadge
                    categoryBadge
                    stateBadge
                }
            }

            Spacer()

            actionControl
        }
    }

    private var policyBadge: some View {
        badge(row.policy.label, systemImage: row.policy.systemImage)
    }

    private var categoryBadge: some View {
        badge(row.category.displayName, systemImage: row.category.systemImage)
    }

    private var stateBadge: some View {
        badge(isEnabled ? "已启用" : "未启用", systemImage: isEnabled ? "checkmark.circle" : "circle")
    }

    @ViewBuilder
    private var actionControl: some View {
        if row.policy.isConfigurable {
            Toggle(
                "",
                isOn: Binding(
                    get: { pluginService.isPluginEnabled(row.plugin) },
                    set: { pluginService.setPlugin(row.plugin, enabled: $0) }
                )
            )
            .toggleStyle(.switch)
            .labelsHidden()
        } else {
            Label(row.policy == .alwaysOn ? "Always On" : "Disabled", systemImage: row.policy == .alwaysOn ? "lock.fill" : "slash.circle")
                .font(.appCaptionEmphasized)
                .foregroundStyle(theme.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .appSurface(style: .subtle, cornerRadius: 7)
        }
    }

    private var defaultDetail: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("插件说明")
                .font(.appBodyEmphasized)
                .foregroundStyle(theme.textPrimary)

            Text(row.description.isEmpty ? "该插件暂未提供自定义介绍视图。" : row.description)
                .font(.appCaption)
                .foregroundStyle(theme.textSecondary)

            VStack(alignment: .leading, spacing: 10) {
                infoRow("插件 ID", value: row.id)
                infoRow("加载策略", value: row.policy.label)
                infoRow("分类", value: row.category.displayName)
                infoRow("排序", value: "\(row.order)")
            }
            .padding(14)
            .appSurface(style: .subtle, cornerRadius: 8)
        }
    }

    private func infoRow(_ label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.appCaption)
                .foregroundStyle(theme.textSecondary)
                .frame(width: 72, alignment: .leading)
            Text(value)
                .font(.appCaptionEmphasized)
                .foregroundStyle(theme.textPrimary)
                .textSelection(.enabled)
        }
    }

    private func badge(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.appMicro)
            .foregroundStyle(theme.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .appSurface(style: .subtle, cornerRadius: 6)
    }
}

private struct PluginSettingsRowModel: Identifiable {
    let plugin: any LumiPlugin.Type

    var id: String { plugin.info.id }
    var displayName: String { plugin.info.displayName }
    var description: String { plugin.info.description }
    var order: Int { plugin.info.order }
    var iconName: String { plugin.iconName }
    var category: LumiPluginCategory { plugin.category }
    var policy: LumiPluginPolicy { plugin.policy }
}

private extension LumiPluginPolicy {
    var label: String {
        switch self {
        case .alwaysOn: "Always On"
        case .optOut: "Opt Out"
        case .optIn: "Opt In"
        case .disabled: "Disabled"
        }
    }

    var systemImage: String {
        switch self {
        case .alwaysOn: "lock.fill"
        case .optOut: "checkmark.circle"
        case .optIn: "power"
        case .disabled: "slash.circle"
        }
    }
}
