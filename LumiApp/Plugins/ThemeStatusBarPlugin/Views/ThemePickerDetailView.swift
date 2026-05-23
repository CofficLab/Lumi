import SwiftUI
import LumiUI

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
        case .all: return true
        case .dark: return kind == .dark
        case .light: return kind == .light
        case .system: return kind == .system
        }
    }
}

struct ThemePickerDetailView: View {
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
