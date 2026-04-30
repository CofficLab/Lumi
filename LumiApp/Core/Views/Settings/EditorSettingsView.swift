import SwiftUI

struct EditorSettingsView: View {
    @ObservedObject private var settingsState = EditorSettingsState.shared
    @State private var searchText = ""

    private var builtInSections: [EditorSettingsSectionModel] {
        [
            EditorSettingsSectionModel(
                id: "editor.typography",
                title: "字体与缩进",
                subtitle: "控制编辑器的基本排版、缩进宽度和制表符策略。",
                entries: [
                    .init(
                        id: "editor.font-size",
                        title: "字体大小",
                        subtitle: "调整 source editor 的默认字号。",
                        keywords: ["font", "font size", "字号", "字体"],
                        content: { state in
                            AnyView(
                                EditorStepperSettingRow(
                                    title: "字体大小",
                                    subtitle: "当前 \(Int(state.fontSize)) pt",
                                    value: Binding(
                                        get: { Int(state.fontSize) },
                                        set: { state.fontSize = Double($0) }
                                    ),
                                    range: 10...28
                                )
                            )
                        }
                    ),
                    .init(
                        id: "editor.tab-width",
                        title: "Tab Size",
                        subtitle: "控制缩进宽度和软制表符长度。",
                        keywords: ["tab", "tab size", "indent", "缩进"],
                        content: { state in
                            AnyView(
                                EditorSegmentedSettingRow(
                                    title: "Tab Size",
                                    subtitle: "代码缩进默认宽度",
                                    selection: Binding(
                                        get: { state.tabWidth },
                                        set: { state.tabWidth = $0 }
                                    ),
                                    options: [2, 4, 8]
                                )
                            )
                        }
                    ),
                    .init(
                        id: "editor.use-spaces",
                        title: "Insert Spaces",
                        subtitle: "使用空格替代真实 Tab 字符。",
                        keywords: ["spaces", "tabs", "indent", "空格", "tab"],
                        content: { state in
                            AnyView(
                                EditorToggleSettingRow(
                                    title: "Insert Spaces",
                                    subtitle: "输入缩进时优先插入空格",
                                    isOn: Binding(
                                        get: { state.useSpaces },
                                        set: { state.useSpaces = $0 }
                                    )
                                )
                            )
                        }
                    )
                ]
            ),
            EditorSettingsSectionModel(
                id: "editor.display",
                title: "显示选项",
                subtitle: "控制行号、换行、折叠和 minimap 等可视表面。",
                entries: [
                    .init(
                        id: "editor.wrap-lines",
                        title: "Word Wrap",
                        subtitle: "长行在视口宽度内自动折返。",
                        keywords: ["wrap", "word wrap", "自动换行"],
                        content: { state in
                            AnyView(
                                EditorToggleSettingRow(
                                    title: "Word Wrap",
                                    subtitle: "超长文本在当前视口内换行显示",
                                    isOn: Binding(
                                        get: { state.wrapLines },
                                        set: { state.wrapLines = $0 }
                                    )
                                )
                            )
                        }
                    ),
                    .init(
                        id: "editor.minimap",
                        title: "Minimap",
                        subtitle: "在右侧显示文档概览；大文件模式下可能被强制关闭。",
                        keywords: ["minimap", "overview", "概览"],
                        content: { state in
                            AnyView(
                                EditorToggleSettingRow(
                                    title: "Minimap",
                                    subtitle: "显示右侧文档概览",
                                    isOn: Binding(
                                        get: { state.showMinimap },
                                        set: { state.showMinimap = $0 }
                                    )
                                )
                            )
                        }
                    ),
                    .init(
                        id: "editor.line-numbers",
                        title: "Line Numbers",
                        subtitle: "显示左侧 gutter 与行号。",
                        keywords: ["line numbers", "gutter", "行号"],
                        content: { state in
                            AnyView(
                                EditorToggleSettingRow(
                                    title: "Line Numbers",
                                    subtitle: "显示 gutter、行号与左侧 marker",
                                    isOn: Binding(
                                        get: { state.showGutter },
                                        set: { state.showGutter = $0 }
                                    )
                                )
                            )
                        }
                    ),
                    .init(
                        id: "editor.folding",
                        title: "Code Folding",
                        subtitle: "显示折叠 ribbon 与折叠摘要。",
                        keywords: ["folding", "fold", "折叠"],
                        content: { state in
                            AnyView(
                                EditorToggleSettingRow(
                                    title: "Code Folding",
                                    subtitle: "显示折叠控制与折叠摘要",
                                    isOn: Binding(
                                        get: { state.showFoldingRibbon },
                                        set: { state.showFoldingRibbon = $0 }
                                    )
                                )
                            )
                        }
                    ),
                    .init(
                        id: "editor.render-whitespace",
                        title: "Render Whitespace",
                        subtitle: "当前底层 editor engine 尚未开放独立 whitespace 渲染开关。",
                        keywords: ["render whitespace", "whitespace", "空白字符"],
                        content: { state in
                            AnyView(
                                EditorReadOnlySettingRow(
                                    title: "Render Whitespace",
                                    subtitle: state.supportsRenderWhitespace
                                        ? "Whitespace rendering is available."
                                        : "Unavailable in the current source editor backend.",
                                    badge: state.supportsRenderWhitespace ? "Available" : "Unavailable"
                                )
                            )
                        }
                    )
                ]
            ),
            EditorSettingsSectionModel(
                id: "editor.save-pipeline",
                title: "保存行为",
                subtitle: "控制保存时的格式化、imports 和清理策略。",
                entries: [
                    .init(
                        id: "editor.format-on-save",
                        title: "Format On Save",
                        subtitle: "保存时尝试运行格式化。",
                        keywords: ["format on save", "save", "格式化"],
                        content: { state in
                            AnyView(
                                EditorToggleSettingRow(
                                    title: "Format On Save",
                                    subtitle: "保存文件时自动触发格式化",
                                    isOn: Binding(
                                        get: { state.formatOnSave },
                                        set: { state.formatOnSave = $0 }
                                    )
                                )
                            )
                        }
                    ),
                    .init(
                        id: "editor.organize-imports-on-save",
                        title: "Organize Imports On Save",
                        subtitle: "保存时请求 LSP 整理 imports。",
                        keywords: ["organize imports", "imports", "save"],
                        content: { state in
                            AnyView(
                                EditorToggleSettingRow(
                                    title: "Organize Imports On Save",
                                    subtitle: "保存时整理 imports",
                                    isOn: Binding(
                                        get: { state.organizeImportsOnSave },
                                        set: { state.organizeImportsOnSave = $0 }
                                    )
                                )
                            )
                        }
                    ),
                    .init(
                        id: "editor.fix-all-on-save",
                        title: "Fix All On Save",
                        subtitle: "保存时请求 LSP 执行 source.fixAll。",
                        keywords: ["fix all", "save", "code actions"],
                        content: { state in
                            AnyView(
                                EditorToggleSettingRow(
                                    title: "Fix All On Save",
                                    subtitle: "保存时运行 source.fixAll",
                                    isOn: Binding(
                                        get: { state.fixAllOnSave },
                                        set: { state.fixAllOnSave = $0 }
                                    )
                                )
                            )
                        }
                    ),
                    .init(
                        id: "editor.trim-trailing-whitespace",
                        title: "Trim Trailing Whitespace",
                        subtitle: "保存时移除每行末尾多余空格。",
                        keywords: ["trim trailing whitespace", "whitespace", "save"],
                        content: { state in
                            AnyView(
                                EditorToggleSettingRow(
                                    title: "Trim Trailing Whitespace",
                                    subtitle: "保存时清理行尾空白",
                                    isOn: Binding(
                                        get: { state.trimTrailingWhitespaceOnSave },
                                        set: { state.trimTrailingWhitespaceOnSave = $0 }
                                    )
                                )
                            )
                        }
                    ),
                    .init(
                        id: "editor.insert-final-newline",
                        title: "Insert Final Newline",
                        subtitle: "保存时确保文件结尾带换行。",
                        keywords: ["final newline", "newline", "save"],
                        content: { state in
                            AnyView(
                                EditorToggleSettingRow(
                                    title: "Insert Final Newline",
                                    subtitle: "保存时补齐文件末尾换行",
                                    isOn: Binding(
                                        get: { state.insertFinalNewlineOnSave },
                                        set: { state.insertFinalNewlineOnSave = $0 }
                                    )
                                )
                            )
                        }
                    )
                ]
            )
        ]
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

                    ForEach(allSections) { section in
                        sectionCard(section)
                    }

                    if extensionSections.isEmpty {
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

    private var extensionEmptyStateCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: AppUI.Spacing.sm) {
                GlassSectionHeader(
                    icon: "slider.horizontal.3",
                    title: "扩展设置",
                    subtitle: "当前没有 editor 扩展向此页贡献设置项。"
                )

                Text("后续插件只要注册 `EditorSettingsContributor`，设置项就会自动出现在这里。")
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

private struct EditorToggleSettingRow: View {
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

private struct EditorStepperSettingRow: View {
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

private struct EditorSegmentedSettingRow: View {
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

private struct EditorReadOnlySettingRow: View {
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

#Preview("Editor Settings") {
    EditorSettingsView()
        .inRootView()
}
