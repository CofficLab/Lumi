import LumiCoreKit
import LumiChatKit
import LumiUI
import SwiftUI

struct PluginSettingsPage: View {
    @LumiTheme private var theme
    @ObservedObject var lumiCore: LumiCore
    @ObservedObject var pluginService: PluginService
    @ObservedObject var chatService: ChatService
    @State private var selectedCategory: LumiPluginCategory?
    @State private var selectedPluginID: String?
    @State private var searchText = ""


    init(
        lumiCore: LumiCore,
        pluginService: PluginService,
        chatService: ChatService
    ) {
        self.lumiCore = lumiCore
        self.pluginService = pluginService
        self.chatService = chatService
    }
    private var pluginRows: [PluginSettingsRowModel] {
        pluginService.plugins
            .filter { $0.policy != .alwaysOn }
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
            Text(String(format: String(localized: "%lld enabled"), enabledCount))
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
            AppTag(title, systemImage: systemImage, style: isSelected ? .accent : .subtle)
        }
        .buttonStyle(.plain)
    }

    private func pluginListRow(_ row: PluginSettingsRowModel) -> some View {
        let isSelected = selectedPluginID == row.id
        let isEnabled = pluginService.isPluginEnabled(row.plugin)

        return AppListRow(isSelected: isSelected, action: { selectedPluginID = row.id }) {
            HStack(alignment: .top, spacing: 10) {
                VStack(spacing: 6) {
                    Image(systemName: row.iconName)
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
                        Text(row.displayName)
                            .font(.appCaptionEmphasized)
                            .foregroundStyle(theme.textPrimary)
                            .lineLimit(1)
                    }

                    Text(row.description.isEmpty ? row.id : row.description)
                        .font(.appMicro)
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 44)
            }
            .overlay(alignment: .topTrailing) {
                AppTag(row.stage.displayName, style: row.stage == .stable ? .accent : .subtle)
            }
        }
    }

    @ViewBuilder
    private var pluginDetailPane: some View {
        if let selectedRow {
            PluginSettingsDetailView(
                lumiCore: lumiCore,
                row: selectedRow,
                pluginService: pluginService,
                chatService: chatService
            )
        } else {
            AppEmptyState(icon: "puzzlepiece.extension", title: "选择一个插件")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct PluginSettingsDetailView: View {
    @LumiTheme private var theme
    let lumiCore: LumiCore
    let row: PluginSettingsRowModel
    @ObservedObject var pluginService: PluginService
    @ObservedObject var chatService: ChatService

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                enableToggle

                AppDivider()

                pluginSettingsContent
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appSurface(style: .panel, cornerRadius: 0)
    }

    @ViewBuilder
    private var pluginSettingsContent: some View {
        let settingsViews = row.plugin.addSettingsView(context: settingsContext)
        if !settingsViews.isEmpty {
            ForEach(Array(settingsViews.enumerated()), id: \.offset) { _, view in
                view
            }
        } else {
            AppEmptyState(
                icon: "puzzlepiece.extension",
                title: String(localized: "该插件暂未提供设置页面。")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var settingsContext: LumiPluginContext {
        lumiCore.makePluginContext(
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
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, 56)
        }
        .overlay(alignment: .topTrailing) {
            AppTag(row.stage.displayName, style: row.stage == .stable ? .accent : .subtle)
        }
    }

    @ViewBuilder
    private var enableToggle: some View {
        if row.policy.isConfigurable {
            AppSettingsToggleRow(
                "启用",
                isOn: Binding(
                    get: { pluginService.isPluginEnabled(row.plugin) },
                    set: { pluginService.setPlugin(row.plugin, enabled: $0) }
                )
            )
            .frame(maxWidth: 140)
        } else {
            AppTag(
                row.policy == .alwaysOn ? "Always On" : "Disabled",
                systemImage: row.policy == .alwaysOn ? "lock.fill" : "slash.circle"
            )
        }
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
    var stage: LumiPluginStage { plugin.stage }
}
