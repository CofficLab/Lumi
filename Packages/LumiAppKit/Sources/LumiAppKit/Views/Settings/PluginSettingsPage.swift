import LumiLocalizationKit
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
            Label(
                String(format: LumiLocalization.string("%lld 个插件", bundle: .module), pluginRows.count),
                systemImage: "puzzlepiece.extension"
            )
            Text(String(format: LumiLocalization.string("%lld enabled", bundle: .module), enabledCount))
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
                        AppEmptyState(icon: "magnifyingglass", title: LumiLocalization.string("未找到插件", bundle: .module))
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
                categoryTab(LumiLocalization.string("全部", bundle: .module), systemImage: "square.grid.2x2", isSelected: selectedCategory == nil) {
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
            AppEmptyState(icon: "puzzlepiece.extension", title: LumiLocalization.string("选择一个插件", bundle: .module))
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

                if let failure = pluginFailure {
                    pluginFailureBanner(failure)
                }

                AppDivider()

                pluginSettingsContent
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appSurface(style: .panel, cornerRadius: 0)
    }

    /// 当前插件在最近一次工具收集中的失败记录（若有）。
    /// 数据源是 `AgentToolComponent.toolContributionFailures`，由 PluginService
    /// 的 objectWillChange 触发刷新（RootContainer 在工具重编排后调用）。
    private var pluginFailure: LumiPluginContributionFailure? {
        lumiCore.agentToolComponent.toolContributionFailures.first { $0.pluginID == row.id }
    }

    /// 错误 banner：风格对齐 `AppErrorBanner`（红底 + 红边 + 三角图标 + 红字），
    /// 但支持动态 `String` 错误描述（AppErrorBanner 的 message 是 LocalizedStringKey，
    /// 无法承载运行时错误文本）。使用与本文件其余部分一致的字面量 + `.appCaption`
    /// 系列 modifier（LumiAppKit 不直接引用 LumiUI 的 internal `AppUI` 命名空间）。
    @ViewBuilder
    private func pluginFailureBanner(_ failure: LumiPluginContributionFailure) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14))
                .foregroundColor(theme.error)

            VStack(alignment: .leading, spacing: 2) {
                Text(LumiLocalization.string("此插件未能注册工具", bundle: .module))
                    .font(.appCaptionEmphasized)
                    .foregroundColor(theme.error)

                Text(failure.errorDescription)
                    .font(.appMicro)
                    .foregroundColor(theme.error)
                    .lineLimit(nil)
                    .textSelection(.enabled)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(theme.error.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(theme.error.opacity(0.2), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var pluginSettingsContent: some View {
        if let about = row.plugin.pluginAboutView(context: settingsContext) {
            about
        } else {
            AppEmptyState(
                icon: "info.circle",
                title: LumiLocalization.string("该插件未提供详细信息", bundle: .module),
                description: LumiLocalization.string(
                    "插件作者可以实现 pluginAboutView 来丰富此页面。",
                    bundle: .module
                )
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var settingsContext: LumiPluginContext {
        lumiCore.makePluginContext(
            activeSectionID: "settings.plugins",
            activeSectionTitle: LumiLocalization.string("插件管理", bundle: .module)
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
                LumiLocalization.string("启用", bundle: .module),
                isOn: Binding(
                    get: { pluginService.isPluginEnabled(row.plugin) },
                    set: { pluginService.setPlugin(row.plugin, enabled: $0) }
                )
            )
            .frame(maxWidth: 140)
        } else {
            AppTag(
                row.policy == .alwaysOn ? LumiLocalization.string("Always On", bundle: .module) : LumiLocalization.string("Disabled", bundle: .module),
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
