import LumiCoreKit
import LumiUI
import PluginThemeStatusBar
import SuperLogKit
import SwiftUI
import os

actor ThemeStatusBarPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = PluginThemeStatusBar.ThemeStatusBarPlugin.logger
    nonisolated static let emoji = PluginThemeStatusBar.ThemeStatusBarPlugin.emoji
    nonisolated static let verbose = PluginThemeStatusBar.ThemeStatusBarPlugin.verbose

    static let id = PluginThemeStatusBar.ThemeStatusBarPlugin.id
    static let displayName = PluginThemeStatusBar.ThemeStatusBarPlugin.displayName
    static let description = PluginThemeStatusBar.ThemeStatusBarPlugin.description
    static let iconName = PluginThemeStatusBar.ThemeStatusBarPlugin.iconName
    static var category: PluginCategory { PluginCategory(package: PluginThemeStatusBar.ThemeStatusBarPlugin.category) }
    static var order: Int { PluginThemeStatusBar.ThemeStatusBarPlugin.order }

    nonisolated var instanceLabel: String { Self.id }
    static let shared = ThemeStatusBarPlugin()
    nonisolated func onRegister() {}

    @MainActor
    func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        AnyView(ThemePersistenceAnchor(content: content()))
    }

    @MainActor
    func addStatusBarTrailingView(context: PluginContext) -> AnyView? {
        AnyView(ThemeStatusBarView())
    }
}

private struct ThemePersistenceAnchor<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeVM: AppThemeVM
    @EnvironmentObject private var editorVM: WindowEditorVM
    let content: Content

    @State private var hasRestored = false

    var body: some View {
        content
            .onAppear {
                restoreSavedTheme()
                syncEditorThemeToWindow()
            }
            .onChange(of: colorScheme) { _, _ in
                syncEditorThemeToWindow()
            }
            .onChange(of: themeVM.currentThemeId) { oldValue, newValue in
                guard hasRestored else { return }
                guard oldValue != newValue else { return }
                if ThemeStatusBarPlugin.verbose {
                    ThemeStatusBarPlugin.logger.info("\(ThemeStatusBarPlugin.t)主题变更: \(oldValue, privacy: .public) -> \(newValue, privacy: .public)")
                }
                ThemeStatusBarPluginLocalStore.shared.saveSelectedThemeID(newValue)
                syncEditorThemeToWindow()
            }
    }

    private func syncEditorThemeToWindow() {
        guard let contribution = themeVM.currentTheme ?? themeVM.themes.first else { return }
        let editorThemeId = contribution.chromeTheme.resolvedEditorThemeId(
            defaultEditorThemeId: contribution.editorThemeId,
            colorScheme: effectiveColorScheme(for: contribution.chromeTheme)
        )
        if ThemeStatusBarPlugin.verbose {
            ThemeStatusBarPlugin.logger.info("\(ThemeStatusBarPlugin.t)同步编辑器主题 -> \(editorThemeId, privacy: .public)")
        }
        editorVM.syncInitialEditorTheme(editorThemeId)
    }

    private func restoreSavedTheme() {
        guard !hasRestored else { return }
        hasRestored = true

        guard let savedId = ThemeStatusBarPluginLocalStore.shared.loadSelectedThemeID() else {
            if ThemeStatusBarPlugin.verbose {
                ThemeStatusBarPlugin.logger.info("\(ThemeStatusBarPlugin.t)无已保存主题，使用默认主题")
            }
            return
        }
        if ThemeStatusBarPlugin.verbose {
            ThemeStatusBarPlugin.logger.info("\(ThemeStatusBarPlugin.t)恢复已保存主题: \(savedId, privacy: .public)")
        }
        themeVM.selectTheme(savedId)
    }

    private func effectiveColorScheme(for chromeTheme: any LumiAppChromeTheme) -> ColorScheme {
        if chromeTheme.followsSystemAppearance {
            return SystemAppearanceResolver.effectiveColorScheme
        }
        return colorScheme
    }
}

private struct ThemeStatusBarView: View {
    @EnvironmentObject private var themeVM: AppThemeVM

    var body: some View {
        StatusBarHoverContainer(
            detailView: ThemePickerDetailView(),
            popoverWidth: 320,
            id: "lumi-theme-picker"
        ) {
            HStack(spacing: 4) {
                Image(systemName: "paintbrush")
                    .font(.appMicroEmphasized)
                if let current = themeVM.currentTheme {
                    Text(current.displayName)
                        .font(.appMicro)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }
}

private enum ThemeAppearanceFilter: String, CaseIterable, Identifiable {
    case all
    case dark
    case light
    case system

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            String(localized: "All", table: "ThemeStatusBar")
        case .dark:
            String(localized: "Dark", table: "ThemeStatusBar")
        case .light:
            String(localized: "Light", table: "ThemeStatusBar")
        case .system:
            String(localized: "System", table: "ThemeStatusBar")
        }
    }

    func matches(_ kind: ThemeAppearanceKind) -> Bool {
        switch self {
        case .all: true
        case .dark: kind == .dark
        case .light: kind == .light
        case .system: kind == .system
        }
    }
}

private struct ThemePickerDetailView: View {
    @LumiUI.LumiTheme private var uiTheme: any LumiUITheme
    @EnvironmentObject private var themeVM: AppThemeVM
    @State private var appearanceFilter: ThemeAppearanceFilter = .all

    private var filteredThemes: [LumiUIThemeContribution] {
        themeVM.themes.filter { appearanceFilter.matches($0.appearanceKind) }
    }

    var body: some View {
        StatusBarPopoverScaffold(
            title: String(localized: "Theme", table: "ThemeStatusBar"),
            systemImage: "paintbrush"
        ) {
            if themeVM.themes.isEmpty {
                AppEmptyState(
                    icon: "paintbrush",
                    title: LocalizedStringKey(String(localized: "No themes available", table: "ThemeStatusBar"))
                )
            } else {
                VStack(spacing: 8) {
                    Picker("", selection: $appearanceFilter) {
                        ForEach(ThemeAppearanceFilter.allCases) { filter in
                            Text(filter.title).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    if filteredThemes.isEmpty {
                        AppEmptyState(
                            icon: "line.3.horizontal.decrease.circle",
                            title: LocalizedStringKey(
                                String(localized: "No themes in this category", table: "ThemeStatusBar")
                            )
                        )
                        .frame(minHeight: 180)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 6) {
                                ForEach(filteredThemes) { theme in
                                    themeRow(theme)
                                }
                            }
                        }
                        .frame(minHeight: 220)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func themeRow(_ theme: LumiUIThemeContribution) -> some View {
        let isSelected = theme.id == themeVM.currentThemeId
        AppListRow(isSelected: isSelected, action: {
            themeVM.selectTheme(theme.id)
        }) {
            HStack(spacing: 10) {
                Image(systemName: theme.iconName)
                    .font(.appCaptionEmphasized)
                    .foregroundColor(isSelected ? .white : uiTheme.textSecondary)
                    .frame(width: 20, height: 20)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(isSelected ? theme.iconColor : uiTheme.textTertiary.opacity(0.12))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(theme.displayName)
                        .font(isSelected ? .appCaptionEmphasized : .appCaption)
                        .foregroundColor(isSelected ? uiTheme.textPrimary : uiTheme.textSecondary)
                    Text(theme.description)
                        .font(.appMicro)
                        .foregroundColor(uiTheme.textTertiary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.appMicroEmphasized)
                        .foregroundColor(theme.iconColor)
                }
            }
        }
    }
}
