import SwiftUI

struct EditorSettingsView: View {
    @ObservedObject private var settingsState = EditorSettingsState.shared
    @State private var searchText = ""

    private var builtInSections: [EditorSettingsSectionModel] {
        EditorSettingsCatalog.builtInSections().map { section in
            EditorSettingsSectionModel(
                id: section.id,
                title: section.title,
                subtitle: section.subtitle,
                entries: section.entries.map { entry in
                    EditorSettingsEntryModel(
                        id: entry.id,
                        title: entry.title,
                        subtitle: entry.subtitle,
                        keywords: entry.keywords,
                        content: entry.content
                    )
                }
            )
        }
    }

    private var extensionSections: [EditorSettingsSectionModel] {
        let query = normalizedQuery
        let grouped = Dictionary(grouping: settingsState.contributedSettings.filter { item in
            query.isEmpty || searchableText(for: item).localizedCaseInsensitiveContains(query)
        }, by: \.sectionTitle)

        return grouped.keys.sorted().map { title in
            let items = grouped[title, default: []]
            let sortedItems = items.sorted { lhs, rhs in
                if lhs.order != rhs.order { return lhs.order < rhs.order }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
            return EditorSettingsSectionModel(
                id: "extension.\(title)",
                title: title,
                subtitle: sortedItems.first?.sectionSummary,
                entries: sortedItems.map { item in
                    EditorSettingsEntryModel(
                        id: item.id,
                        title: item.title,
                        subtitle: item.subtitle,
                        keywords: item.keywords,
                        content: item.content
                    )
                }
            )
        }
    }

    private var filteredBuiltInSections: [EditorSettingsSectionModel] {
        let query = normalizedQuery
        guard !query.isEmpty else { return builtInSections }
        return builtInSections.compactMap { section in
            let entries = section.entries.filter {
                searchableText(for: $0).localizedCaseInsensitiveContains(query)
            }
            guard !entries.isEmpty else { return nil }
            return EditorSettingsSectionModel(
                id: section.id,
                title: section.title,
                subtitle: section.subtitle,
                entries: entries
            )
        }
    }

    private var normalizedQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var allSections: [EditorSettingsSectionModel] {
        filteredBuiltInSections + extensionSections
    }

    var body: some View {
        VStack(spacing: 0) {
            headerCard
                .padding(AppUI.Spacing.lg)
                .background(Color.clear)

            ScrollView {
                VStack(alignment: .leading, spacing: AppUI.Spacing.lg) {
                    searchCard
                    scopedOverridesCard

                    ForEach(allSections) { section in
                        sectionCard(section)
                    }

                    if normalizedQuery.isEmpty && extensionSections.isEmpty {
                        extensionEmptyStateCard
                    }

                    if allSections.isEmpty {
                        emptySearchCard
                    }

                    Spacer()
                }
                .padding(.horizontal, AppUI.Spacing.lg)
            }
        }
        .navigationTitle("编辑器设置")
        .onAppear {
            applyPendingSearchQuery()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSettings)) { _ in
            applyPendingSearchQuery()
        }
    }

    private var headerCard: some View {
        GlassCard {
            GlassSectionHeader(
                icon: "chevron.left.forwardslash.chevron.right",
                title: "编辑器设置",
                subtitle: "集中管理字体、缩进、显示和扩展贡献的 editor 偏好项。"
            )
        }
    }

    private var searchCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: AppUI.Spacing.md) {
                GlassSectionHeader(
                    icon: "magnifyingglass",
                    title: "快速筛选",
                    subtitle: "按设置名、关键词或功能名过滤当前 editor settings。"
                )

                GlassDivider()

                TextField("搜索 editor settings", text: $searchText)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    private var scopedOverridesCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: AppUI.Spacing.md) {
                GlassSectionHeader(
                    icon: "slider.horizontal.below.rectangle",
                    title: "作用域覆盖",
                    subtitle: "为当前 workspace 或语言单独覆盖一小组高频编辑行为，解析顺序为 global → workspace → language。"
                )

                GlassDivider()

                Picker("Scope", selection: $settingsState.selectedScope) {
                    ForEach(EditorSettingsScopeSelection.allCases) { scope in
                        Text(scope.title).tag(scope)
                    }
                }
                .pickerStyle(.segmented)

                if settingsState.selectedScope == .language {
                    Picker("Language", selection: $settingsState.selectedLanguageID) {
                        ForEach(settingsState.availableLanguageIDs, id: \.self) { languageId in
                            Text(languageId).tag(languageId)
                        }
                    }
                    .pickerStyle(.menu)
                }

                HStack(spacing: AppUI.Spacing.sm) {
                    Text("当前目标")
                        .font(AppUI.Typography.caption1)
                        .foregroundColor(AppUI.Color.semantic.textSecondary)
                    GlassBadge(text: LocalizedStringKey(settingsState.selectedScope.title), style: .neutral)
                    Text(settingsState.activeOverrideScopeLabel)
                        .font(AppUI.Typography.caption1)
                        .foregroundColor(AppUI.Color.semantic.textTertiary)
                        .lineLimit(2)
                }

                if settingsState.selectedScope == .global {
                    Text("全局设置继续在下方分组里编辑；覆盖层只在 workspace 或 language scope 下启用。")
                        .font(AppUI.Typography.caption1)
                        .foregroundColor(AppUI.Color.semantic.textTertiary)
                } else if settingsState.canEditScopedOverrides {
                    VStack(spacing: 0) {
                        EditorScopedStepperSettingRow(
                            title: "Tab Size Override",
                            subtitle: "只覆盖当前作用域的缩进宽度。",
                            isEnabled: $settingsState.scopedTabWidthEnabled,
                            value: $settingsState.scopedTabWidth,
                            range: 2...8
                        )
                        GlassDivider()
                        EditorScopedToggleSettingRow(
                            title: "Insert Spaces Override",
                            subtitle: "只覆盖当前作用域的空格 / Tab 策略。",
                            isEnabled: $settingsState.scopedUseSpacesEnabled,
                            isOn: $settingsState.scopedUseSpaces
                        )
                        GlassDivider()
                        EditorScopedToggleSettingRow(
                            title: "Word Wrap Override",
                            subtitle: "只覆盖当前作用域的自动换行策略。",
                            isEnabled: $settingsState.scopedWrapLinesEnabled,
                            isOn: $settingsState.scopedWrapLines
                        )
                        GlassDivider()
                        EditorScopedToggleSettingRow(
                            title: "Format On Save Override",
                            subtitle: "只覆盖当前作用域的保存时格式化策略。",
                            isEnabled: $settingsState.scopedFormatOnSaveEnabled,
                            isOn: $settingsState.scopedFormatOnSave
                        )
                    }
                } else {
                    Text("当前还没有可用的 workspace 上下文。先打开一个项目，再回到这里设置 workspace override。")
                        .font(AppUI.Typography.caption1)
                        .foregroundColor(AppUI.Color.semantic.textTertiary)
                }
            }
        }
    }

    private var extensionEmptyStateCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: AppUI.Spacing.sm) {
                GlassSectionHeader(
                    icon: "slider.horizontal.3",
                    title: "扩展设置",
                    subtitle: "当前没有 editor 扩展向此页贡献设置项。"
                )

                Text("后续插件只要注册 `SuperEditorSettingsContributor`，设置项就会自动出现在这里。")
                    .font(AppUI.Typography.caption1)
                    .foregroundColor(AppUI.Color.semantic.textTertiary)
            }
        }
    }

    private var emptySearchCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: AppUI.Spacing.sm) {
                Text("没有匹配的设置项")
                    .font(AppUI.Typography.bodyEmphasized)
                Text("换一个关键词，或清空搜索查看全部 editor settings。")
                    .font(AppUI.Typography.caption1)
                    .foregroundColor(AppUI.Color.semantic.textTertiary)
            }
        }
    }

    private func sectionCard(_ section: EditorSettingsSectionModel) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: AppUI.Spacing.md) {
                GlassSectionHeader(
                    icon: icon(for: section.id),
                    title: section.title,
                    subtitle: section.subtitle ?? ""
                )

                GlassDivider()

                VStack(spacing: 0) {
                    ForEach(section.entries) { entry in
                        entry.content(settingsState)

                        if entry.id != section.entries.last?.id {
                            GlassDivider()
                        }
                    }
                }
            }
        }
    }

    private func searchableText(for item: EditorSettingsItemSuggestion) -> String {
        ([item.sectionTitle, item.title, item.subtitle ?? ""] + item.keywords).joined(separator: " ")
    }

    private func searchableText(for entry: EditorSettingsEntryModel) -> String {
        ([entry.title, entry.subtitle ?? ""] + entry.keywords).joined(separator: " ")
    }

    private func icon(for sectionID: String) -> String {
        switch sectionID {
        case "editor.typography":
            return "textformat.size"
        case "editor.display":
            return "rectangle.3.group"
        case "editor.save-pipeline":
            return "square.and.arrow.down"
        default:
            return "slider.horizontal.3"
        }
    }

    private func applyPendingSearchQuery() {
        guard let pendingQuery = AppSettingStore.consumePendingEditorSettingsSearchQuery() else { return }
        searchText = pendingQuery
    }
}

private struct EditorSettingsSectionModel: Identifiable {
    let id: String
    let title: String
    let subtitle: String?
    let entries: [EditorSettingsEntryModel]
}

private struct EditorSettingsEntryModel: Identifiable {
    let id: String
    let title: String
    let subtitle: String?
    let keywords: [String]
    let content: (EditorSettingsState) -> AnyView
}

struct EditorToggleSettingRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        GlassRow {
            HStack(spacing: AppUI.Spacing.md) {
                VStack(alignment: .leading, spacing: AppUI.Spacing.xs) {
                    Text(title)
                        .font(AppUI.Typography.bodyEmphasized)
                    Text(subtitle)
                        .font(AppUI.Typography.caption1)
                        .foregroundColor(AppUI.Color.semantic.textTertiary)
                }

                Spacer()

                Toggle("", isOn: $isOn)
                    .labelsHidden()
            }
        }
    }
}

struct EditorStepperSettingRow: View {
    let title: String
    let subtitle: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        GlassRow {
            HStack(spacing: AppUI.Spacing.md) {
                VStack(alignment: .leading, spacing: AppUI.Spacing.xs) {
                    Text(title)
                        .font(AppUI.Typography.bodyEmphasized)
                    Text(subtitle)
                        .font(AppUI.Typography.caption1)
                        .foregroundColor(AppUI.Color.semantic.textTertiary)
                }

                Spacer()

                Stepper(value: $value, in: range) {
                    Text("\(value)")
                        .frame(minWidth: 28, alignment: .trailing)
                }
                .frame(width: 112)
            }
        }
    }
}

struct EditorSegmentedSettingRow: View {
    let title: String
    let subtitle: String
    @Binding var selection: Int
    let options: [Int]

    var body: some View {
        GlassRow {
            HStack(spacing: AppUI.Spacing.md) {
                VStack(alignment: .leading, spacing: AppUI.Spacing.xs) {
                    Text(title)
                        .font(AppUI.Typography.bodyEmphasized)
                    Text(subtitle)
                        .font(AppUI.Typography.caption1)
                        .foregroundColor(AppUI.Color.semantic.textTertiary)
                }

                Spacer()

                Picker(title, selection: $selection) {
                    ForEach(options, id: \.self) { option in
                        Text("\(option)").tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
            }
        }
    }
}

struct EditorReadOnlySettingRow: View {
    let title: String
    let subtitle: String
    let badge: String

    var body: some View {
        GlassRow {
            HStack(spacing: AppUI.Spacing.md) {
                VStack(alignment: .leading, spacing: AppUI.Spacing.xs) {
                    Text(title)
                        .font(AppUI.Typography.bodyEmphasized)
                    Text(subtitle)
                        .font(AppUI.Typography.caption1)
                        .foregroundColor(AppUI.Color.semantic.textTertiary)
                }

                Spacer()

                Text(badge)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(AppUI.Color.semantic.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(AppUI.Color.semantic.textTertiary.opacity(0.12))
                    )
            }
        }
    }
}

struct EditorScopedToggleSettingRow: View {
    let title: String
    let subtitle: String
    @Binding var isEnabled: Bool
    @Binding var isOn: Bool

    var body: some View {
        GlassRow {
            VStack(alignment: .leading, spacing: AppUI.Spacing.sm) {
                HStack(spacing: AppUI.Spacing.md) {
                    VStack(alignment: .leading, spacing: AppUI.Spacing.xs) {
                        Text(title)
                            .font(AppUI.Typography.bodyEmphasized)
                        Text(subtitle)
                            .font(AppUI.Typography.caption1)
                            .foregroundColor(AppUI.Color.semantic.textTertiary)
                    }

                    Spacer()

                    Toggle("Override", isOn: $isEnabled)
                        .labelsHidden()
                }

                Toggle("Value", isOn: $isOn)
                    .labelsHidden()
                    .disabled(!isEnabled)
                    .opacity(isEnabled ? 1 : 0.45)
            }
        }
    }
}

struct EditorScopedStepperSettingRow: View {
    let title: String
    let subtitle: String
    @Binding var isEnabled: Bool
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        GlassRow {
            VStack(alignment: .leading, spacing: AppUI.Spacing.sm) {
                HStack(spacing: AppUI.Spacing.md) {
                    VStack(alignment: .leading, spacing: AppUI.Spacing.xs) {
                        Text(title)
                            .font(AppUI.Typography.bodyEmphasized)
                        Text(subtitle)
                            .font(AppUI.Typography.caption1)
                            .foregroundColor(AppUI.Color.semantic.textTertiary)
                    }

                    Spacer()

                    Toggle("Override", isOn: $isEnabled)
                        .labelsHidden()
                }

                Stepper(value: $value, in: range) {
                    Text("\(value) spaces")
                        .font(AppUI.Typography.caption1)
                }
                .disabled(!isEnabled)
                .opacity(isEnabled ? 1 : 0.45)
            }
        }
    }
}

#Preview("Editor Settings") {
    EditorSettingsView()
        .inRootView()
}
