import LumiUI
import ProviderTheme
import SwiftUI

private typealias AppThemeValue = ProviderTheme.LumiTheme
private typealias AppThemeAppearanceKind = ProviderTheme.ThemeAppearanceKind

private enum ThemeAppearanceFilter: String, CaseIterable, Identifiable {
    case all, dark, light, system

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "全部"
        case .dark: "深色"
        case .light: "浅色"
        case .system: "跟随系统"
        }
    }

    func matches(_ kind: AppThemeAppearanceKind) -> Bool {
        switch self {
        case .all: true
        case .dark: kind == .dark
        case .light: kind == .light
        case .system: kind == .system
        }
    }
}

/// 外观设置详情：使用新版 ProviderTheme，恢复旧版的搜索、筛选、双栏浏览、
/// 主题预览与显式应用状态。
@MainActor
struct ThemeSettingsDetailView: View {
    let theme: any ThemeProviding

    @LumiUI.LumiTheme private var uiTheme: any LumiUI.LumiUITheme
    @State private var selectedID: String?
    @State private var searchText = ""
    @State private var appearanceFilter: ThemeAppearanceFilter = .all

    private var filteredThemes: [AppThemeValue] {
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return theme.themes.filter { item in
            appearanceFilter.matches(item.appearanceKind)
                && (keyword.isEmpty
                    || item.displayName.localizedCaseInsensitiveContains(keyword)
                    || item.description.localizedCaseInsensitiveContains(keyword)
                    || item.id.localizedCaseInsensitiveContains(keyword))
        }
    }

    private var selectedTheme: AppThemeValue? {
        if let selectedID, let item = theme.themes.first(where: { $0.id == selectedID }) {
            return item
        }
        return filteredThemes.first ?? theme.themes.first
    }

    var body: some View {
        AppSettingsContentScaffold(scrollsContent: false, maxContentWidth: nil) {
            VStack(alignment: .leading, spacing: 14) {
                headerStats

                HStack(spacing: 0) {
                    themeListPane.frame(width: 300)
                    AppDivider(.vertical)
                    themeDetailPane
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                .frame(minHeight: 520, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(uiTheme.divider, lineWidth: 1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .onAppear { selectedID = theme.selectedThemeId ?? selectedTheme?.id }
        .onReceive(theme.objectWillChange) { _ in selectedID = theme.selectedThemeId }
        .onChange(of: filteredThemes.map(\.id)) { _, ids in
            guard let selectedID, ids.contains(selectedID) else {
                self.selectedID = ids.first
                return
            }
        }
    }

    private var headerStats: some View {
        HStack(spacing: 10) {
            Label("\(theme.themes.count) 个主题", systemImage: "paintpalette")
            if let activeID = theme.selectedThemeId,
               let active = theme.themes.first(where: { $0.id == activeID }) {
                Text("当前：\(active.displayName)")
            }
            Spacer()
        }
        .font(.appCaption)
        .foregroundStyle(uiTheme.textSecondary)
    }

    private var themeListPane: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                AppSearchBar(text: $searchText, placeholder: "搜索主题")
                Picker("主题类型", selection: $appearanceFilter) {
                    ForEach(ThemeAppearanceFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            .padding(12)

            AppDivider()

            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(filteredThemes) { item in themeListRow(item) }
                    if filteredThemes.isEmpty {
                        AppEmptyState(icon: "magnifyingglass", title: "没有找到主题")
                            .padding(.vertical, 32)
                    }
                }
                .padding(8)
            }
            .frame(maxHeight: .infinity)
        }
        .appSurface(style: .panel, cornerRadius: 0)
    }

    private func themeListRow(_ item: AppThemeValue) -> some View {
        let isSelected = selectedTheme?.id == item.id
        let isActive = theme.selectedThemeId == item.id
        return AppListRow(isSelected: isSelected, action: {
            withAnimation(.easeInOut(duration: 0.2)) { selectedID = item.id }
        }) {
            HStack(alignment: .top, spacing: 10) {
                VStack(spacing: 6) {
                    Image(systemName: item.iconName)
                        .font(.appBody)
                        .foregroundStyle(item.resolvedIconColor)
                        .frame(width: 22, height: 22)
                    Circle()
                        .fill(isActive ? uiTheme.success : uiTheme.textTertiary.opacity(0.45))
                        .frame(width: 6, height: 6)
                }
                .frame(width: 22)

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.displayName)
                        .font(.appCaptionEmphasized)
                        .foregroundStyle(uiTheme.textPrimary)
                        .lineLimit(1)
                    Text(item.description)
                        .font(.appMicro)
                        .foregroundStyle(uiTheme.textSecondary)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private var themeDetailPane: some View {
        if let selectedTheme {
            ThemePreviewPane(
                item: selectedTheme,
                isActive: theme.selectedThemeId == selectedTheme.id,
                onApply: { try? theme.selectTheme(id: selectedTheme.id) }
            )
        } else {
            AppEmptyState(icon: "paintpalette", title: "选择一个主题")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct ThemePreviewPane: View {
    let item: AppThemeValue
    let isActive: Bool
    let onApply: () -> Void

    private var palette: LumiThemePalette { item.palette }
    private var primary: Color { palette.accentPrimary.color() }
    private var secondary: Color { palette.accentSecondary.color() }
    private var background: Color { palette.backgroundMedium.color() }
    private var elevated: Color { palette.backgroundLight.color() }
    private var textPrimary: Color { palette.textPrimary.color() }
    private var textSecondary: Color { palette.textSecondary.color() }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                AppDivider()
                preview
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(background)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: item.iconName)
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(item.resolvedIconColor)
                .frame(width: 64, height: 64)
                .background(primary.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 7) {
                Text(item.displayName)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(textPrimary)
                Text(item.description)
                    .font(.appCaption)
                    .foregroundStyle(textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(appearanceLabel)
                    .font(.appMicro)
                    .foregroundStyle(textSecondary.opacity(0.8))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if isActive {
                AppTag("当前使用", style: .accent)
            } else {
                AppButton("使用此主题", systemImage: "paintbrush.fill", style: .primary, size: .small, action: onApply)
            }
        }
    }

    private var appearanceLabel: String {
        switch item.appearanceKind {
        case .dark: "深色主题"
        case .light: "浅色主题"
        case .system: "跟随系统外观"
        }
    }

    private var preview: some View {
        AppSettingsSection(title: "组件预览", subtitle: "查看常用组件在此主题下的效果", spacing: 12) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(LumiPluginLocalization.string("Primary Text", bundle: .module)).font(.appBody).foregroundStyle(textPrimary)
                    Text(LumiPluginLocalization.string("Secondary Text", bundle: .module)).font(.appCaption).foregroundStyle(textSecondary)
                    Text("主题颜色与层级预览").font(.appMicro).foregroundStyle(textSecondary.opacity(0.75))
                }
                HStack(spacing: 8) {
                    previewButton("主要操作", fill: primary, foreground: .white)
                    previewButton("次要操作", fill: elevated, foreground: textPrimary)
                    previewButton("辅助操作", fill: secondary.opacity(0.18), foreground: secondary)
                }
                HStack(spacing: 10) {
                    colorSwatch("主色", primary)
                    colorSwatch("辅色", secondary)
                    colorSwatch("背景", background)
                    colorSwatch("抬升", elevated)
                }
            }
            .padding(16)
            .background(elevated.opacity(0.45))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func previewButton(_ title: String, fill: Color, foreground: Color) -> some View {
        Text(title)
            .font(.appMicroEmphasized)
            .foregroundStyle(foreground)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(fill)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func colorSwatch(_ title: String, _ color: Color) -> some View {
        VStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(color)
                .frame(width: 44, height: 28)
            Text(title)
                .font(.appMicro)
                .foregroundStyle(textSecondary)
        }
    }
}
