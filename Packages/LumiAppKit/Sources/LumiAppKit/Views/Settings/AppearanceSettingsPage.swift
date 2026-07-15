import LumiLocalizationKit
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
            Label(
                String(localized: "%lld 个主题", bundle: .module, arguments: themes.count),
                systemImage: "paintbrush"
            )
            if let activeID = registry.selectedThemeId,
               let active = themes.first(where: { $0.id == activeID }) {
                Text(String(localized: "当前：%@", bundle: .module, arguments: active.displayName))
            }
            Spacer()
        }
        .font(.appCaption)
        .foregroundStyle(theme.textSecondary)
    }

    private var themeListPane: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                AppSearchBar(text: $searchText, placeholder: LocalizedStringKey(String(localized: "搜索主题", bundle: .module)))
            }
            .padding(12)

            AppDivider()

            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(filteredThemes) { contribution in
                        themeListRow(contribution)
                    }

                    if filteredThemes.isEmpty {
                        AppEmptyState(icon: "magnifyingglass", title: Text(String(localized: "未找到主题", bundle: .module)))
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
            AppEmptyState(icon: "paintbrush", title: Text(String(localized: "选择一个主题", bundle: .module)))
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
                AppTag(Text(String(localized: "使用中", bundle: .module)), style: .accent)
            } else {
                AppButton(Text(String(localized: "使用此主题", bundle: .module)), systemImage: "paintbrush.fill", style: .primary, size: .small, action: onApply)
            }
        }
    }

    private var appearanceLabel: String {
        switch contribution.appearanceKind {
        case .dark:
            return String(localized: "深色主题", bundle: .module)
        case .light:
            return String(localized: "浅色主题", bundle: .module)
        case .system:
            return String(localized: "跟随系统外观", bundle: .module)
        }
    }
}

private struct ThemeComponentPreview: View {
    let theme: any LumiUITheme

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            AppSettingsSection(title: Text(String(localized: "组件预览", bundle: .module)), subtitle: Text(String(localized: "常见 UI 组件在此主题下的样式", bundle: .module)), spacing: 12) {
                VStack(alignment: .leading, spacing: 18) {
                    previewGroup(title: Text(String(localized: "文字", bundle: .module))) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(Text(String(localized: "主要文字 Primary", bundle: .module)))
                                .font(.appBody)
                                .foregroundStyle(theme.textPrimary)
                            Text(Text(String(localized: "次要文字 Secondary", bundle: .module)))
                                .font(.appCaption)
                                .foregroundStyle(theme.textSecondary)
                            Text(Text(String(localized: "辅助文字 Tertiary", bundle: .module)))
                                .font(.appMicro)
                                .foregroundStyle(theme.textTertiary)
                        }
                    }

                    previewGroup(title: Text(String(localized: "按钮", bundle: .module))) {
                        HStack(spacing: 8) {
                            previewButton(Text(String(localized: "Primary", bundle: .module)), background: theme.primary, foreground: .white)
                            previewButton(Text(String(localized: "Secondary", bundle: .module)), background: theme.surface, foreground: theme.textPrimary, border: theme.divider)
                            previewButton(Text(String(localized: "Destructive", bundle: .module)), background: theme.error.opacity(0.15), foreground: theme.error)
                        }
                    }

                    previewGroup(title: Text(String(localized: "标签", bundle: .module))) {
                        HStack(spacing: 8) {
                            previewTag(Text(String(localized: "Accent", bundle: .module)), background: theme.primary.opacity(0.15), foreground: theme.primary)
                            previewTag(Text(String(localized: "Subtle", bundle: .module)), background: theme.elevatedSurface, foreground: theme.textSecondary)
                            previewTag(Text(String(localized: "Success", bundle: .module)), background: theme.success.opacity(0.15), foreground: theme.success)
                        }
                    }

                    previewGroup(title: Text(String(localized: "卡片", bundle: .module))) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(Text(String(localized: "卡片标题", bundle: .module)))
                                .font(.appBodyEmphasized)
                                .foregroundStyle(theme.textPrimary)
                            Text(Text(String(localized: "这是卡片中的说明文字，用于展示表面色与层级。", bundle: .module)))
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

                    previewGroup(title: Text(String(localized: "色板", bundle: .module))) {
                        HStack(spacing: 10) {
                            colorSwatch(Text(String(localized: "Primary", bundle: .module)), color: theme.primary)
                            colorSwatch(Text(String(localized: "Success", bundle: .module)), color: theme.success)
                            colorSwatch(Text(String(localized: "Warning", bundle: .module)), color: theme.warning)
                            colorSwatch(Text(String(localized: "Error", bundle: .module)), color: theme.error)
                        }
                    }
                }
            }
        }
    }

    private func previewGroup<Content: View>(title: Text, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            title
                .font(.appCaptionEmphasized)
                .foregroundStyle(theme.textSecondary)
            content()
        }
    }

    private func previewButton(
        _ title: Text,
        background: Color,
        foreground: Color,
        border: Color? = nil
    ) -> some View {
        title
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

    private func previewTag(_ title: Text, background: Color, foreground: Color) -> some View {
        title
            .font(.appMicro)
            .foregroundStyle(foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(background)
            .clipShape(Capsule())
    }

    private func colorSwatch(_ title: Text, color: Color) -> some View {
        VStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(color)
                .frame(width: 44, height: 28)
            title
                .font(.appMicro)
                .foregroundStyle(theme.textTertiary)
        }
    }
}
