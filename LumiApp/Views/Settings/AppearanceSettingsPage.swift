import LumiUI
import SwiftUI

struct AppearanceSettingsPage: View {
    @LumiTheme private var theme
    @ObservedObject private var registry: LumiUIThemeRegistry
    private let lumiUIService: LumiUIService

    @State private var selectedThemeID: String?
    @State private var searchText = ""

    init(lumiUIService: LumiUIService) {
        self.lumiUIService = lumiUIService
        self.registry = lumiUIService.themeRegistry
    }

    private var themes: [LumiUIThemeContribution] {
        registry.themes
    }

    private var filteredThemes: [LumiUIThemeContribution] {
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return themes }
        return themes.filter { contribution in
            contribution.displayName.localizedCaseInsensitiveContains(keyword)
                || contribution.description.localizedCaseInsensitiveContains(keyword)
                || contribution.id.localizedCaseInsensitiveContains(keyword)
        }
    }

    private var selectedTheme: LumiUIThemeContribution? {
        if let selectedThemeID,
           let theme = themes.first(where: { $0.id == selectedThemeID }) {
            return theme
        }
        return filteredThemes.first ?? themes.first
    }

    var body: some View {
        AppSettingsContentScaffold(scrollsContent: false, maxContentWidth: nil) {
            VStack(alignment: .leading, spacing: 14) {
                headerStats

                HStack(spacing: 0) {
                    themeListPane
                        .frame(width: 300)
                        .frame(maxHeight: .infinity)

                    AppDivider(.vertical)

                    themeDetailPane
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
            if selectedThemeID == nil {
                selectedThemeID = registry.selectedThemeId ?? selectedTheme?.id
            }
        }
        .onChange(of: filteredThemes.map(\.id)) { _, ids in
            guard let selectedThemeID,
                  ids.contains(selectedThemeID)
            else {
                self.selectedThemeID = ids.first
                return
            }
        }
    }

    private var headerStats: some View {
        HStack(spacing: 10) {
            Label("\(themes.count) 个主题", systemImage: "paintbrush")
            if let activeID = registry.selectedThemeId,
               let active = themes.first(where: { $0.id == activeID }) {
                Text("当前：\(active.displayName)")
            }
            Spacer()
        }
        .font(.appCaption)
        .foregroundStyle(theme.textSecondary)
    }

    private var themeListPane: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                AppSearchBar(text: $searchText, placeholder: "搜索主题")
            }
            .padding(12)

            AppDivider()

            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(filteredThemes) { contribution in
                        themeListRow(contribution)
                    }

                    if filteredThemes.isEmpty {
                        AppEmptyState(icon: "magnifyingglass", title: "未找到主题")
                            .padding(.vertical, 32)
                    }
                }
                .padding(8)
            }
            .frame(maxHeight: .infinity)
        }
        .appSurface(style: .panel, cornerRadius: 0)
    }

    private func themeListRow(_ contribution: LumiUIThemeContribution) -> some View {
        let isSelected = selectedTheme?.id == contribution.id
        let isActive = registry.selectedThemeId == contribution.id

        return AppListRow(isSelected: isSelected, action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedThemeID = contribution.id
            }
        }) {
            HStack(alignment: .top, spacing: 10) {
                VStack(spacing: 6) {
                    Image(systemName: contribution.iconName)
                        .font(.appBody)
                        .foregroundStyle(contribution.iconColor)
                        .frame(width: 22, height: 22)

                    Circle()
                        .fill(isActive ? theme.success : theme.textTertiary.opacity(0.5))
                        .frame(width: 6, height: 6)
                }
                .frame(width: 22)

                VStack(alignment: .leading, spacing: 3) {
                    Text(contribution.displayName)
                        .font(.appCaptionEmphasized)
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)

                    Text(contribution.description)
                        .font(.appMicro)
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private var themeDetailPane: some View {
        if let selectedTheme {
            ThemeSettingsDetailView(
                contribution: selectedTheme,
                isActive: registry.selectedThemeId == selectedTheme.id,
                onApply: {
                    try? lumiUIService.selectTheme(id: selectedTheme.id)
                }
            )
        } else {
            AppEmptyState(icon: "paintbrush", title: "选择一个主题")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .appSurface(style: .panel, cornerRadius: 0)
        }
    }
}

private struct ThemeSettingsDetailView: View {
    @LumiTheme private var theme

    let contribution: LumiUIThemeContribution
    let isActive: Bool
    let onApply: () -> Void

    private var previewTheme: any LumiUITheme {
        contribution.uiTheme ?? ChromeToUIThemeAdapter(chrome: contribution.chromeTheme)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                AppDivider()
                ThemeComponentPreview(theme: previewTheme)
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appSurface(style: .panel, cornerRadius: 0)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: contribution.iconName)
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(contribution.iconColor)
                .frame(width: 64, height: 64)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(theme.appAccentSoftFill)
                )

            VStack(alignment: .leading, spacing: 7) {
                Text(contribution.displayName)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(theme.textPrimary)

                Text(contribution.description)
                    .font(.appCaption)
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(appearanceLabel)
                    .font(.appMicro)
                    .foregroundStyle(theme.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, isActive ? 56 : 120)
        }
        .overlay(alignment: .topTrailing) {
            if isActive {
                AppTag("使用中", style: .accent)
            } else {
                AppButton("使用此主题", systemImage: "paintbrush.fill", style: .primary, size: .small, action: onApply)
            }
        }
    }

    private var appearanceLabel: String {
        switch contribution.appearanceKind {
        case .dark:
            return "深色主题"
        case .light:
            return "浅色主题"
        case .system:
            return "跟随系统外观"
        }
    }
}

private struct ThemeComponentPreview: View {
    let theme: any LumiUITheme

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            AppSettingsSection(title: "组件预览", subtitle: "常见 UI 组件在此主题下的样式", spacing: 12) {
                VStack(alignment: .leading, spacing: 18) {
                    previewGroup(title: "文字") {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("主要文字 Primary")
                                .font(.appBody)
                                .foregroundStyle(theme.textPrimary)
                            Text("次要文字 Secondary")
                                .font(.appCaption)
                                .foregroundStyle(theme.textSecondary)
                            Text("辅助文字 Tertiary")
                                .font(.appMicro)
                                .foregroundStyle(theme.textTertiary)
                        }
                    }

                    previewGroup(title: "按钮") {
                        HStack(spacing: 8) {
                            previewButton("Primary", background: theme.primary, foreground: .white)
                            previewButton("Secondary", background: theme.surface, foreground: theme.textPrimary, border: theme.divider)
                            previewButton("Destructive", background: theme.error.opacity(0.15), foreground: theme.error)
                        }
                    }

                    previewGroup(title: "标签") {
                        HStack(spacing: 8) {
                            previewTag("Accent", background: theme.primary.opacity(0.15), foreground: theme.primary)
                            previewTag("Subtle", background: theme.elevatedSurface, foreground: theme.textSecondary)
                            previewTag("Success", background: theme.success.opacity(0.15), foreground: theme.success)
                        }
                    }

                    previewGroup(title: "卡片") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("卡片标题")
                                .font(.appBodyEmphasized)
                                .foregroundStyle(theme.textPrimary)
                            Text("这是卡片中的说明文字，用于展示表面色与层级。")
                                .font(.appCaption)
                                .foregroundStyle(theme.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(theme.elevatedSurface)
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(theme.divider, lineWidth: 1)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    previewGroup(title: "色板") {
                        HStack(spacing: 10) {
                            colorSwatch("Primary", color: theme.primary)
                            colorSwatch("Success", color: theme.success)
                            colorSwatch("Warning", color: theme.warning)
                            colorSwatch("Error", color: theme.error)
                        }
                    }
                }
            }
        }
    }

    private func previewGroup<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.appCaptionEmphasized)
                .foregroundStyle(theme.textSecondary)
            content()
        }
    }

    private func previewButton(
        _ title: String,
        background: Color,
        foreground: Color,
        border: Color? = nil
    ) -> some View {
        Text(title)
            .font(.appMicroEmphasized)
            .foregroundStyle(foreground)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(background)
            .overlay {
                if let border {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(border, lineWidth: 1)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func previewTag(_ title: String, background: Color, foreground: Color) -> some View {
        Text(title)
            .font(.appMicro)
            .foregroundStyle(foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(background)
            .clipShape(Capsule())
    }

    private func colorSwatch(_ title: String, color: Color) -> some View {
        VStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(color)
                .frame(width: 44, height: 28)
            Text(title)
                .font(.appMicro)
                .foregroundStyle(theme.textTertiary)
        }
    }
}
