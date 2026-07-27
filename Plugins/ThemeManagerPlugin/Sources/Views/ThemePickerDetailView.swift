import SwiftUI
import LumiUI
import LumiKernel

private enum ThemeAppearanceFilter: String, CaseIterable, Identifiable {
    case all
    case dark
    case light
    case system

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return LumiPluginLocalization.string("All", bundle: .module)
        case .dark: return LumiPluginLocalization.string("Dark", bundle: .module)
        case .light: return LumiPluginLocalization.string("Light", bundle: .module)
        case .system: return LumiPluginLocalization.string("System", bundle: .module)
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
    @LumiTheme private var uiTheme: any LumiUITheme
    private let themeService: any LumiThemeServicing
    @ObservedObject private var registry: LumiUIThemeRegistry
    @State private var appearanceFilter: ThemeAppearanceFilter = .all

    init(themeService: any LumiThemeServicing) {
        self.themeService = themeService
        self.registry = themeService.themeRegistry
    }

    private var filteredThemes: [LumiUIThemeContribution] {
        registry.themes.filter { appearanceFilter.matches($0.appearanceKind) }
    }

    var body: some View {
        StatusBarPopoverScaffold(
            title: LumiPluginLocalization.string("Theme", bundle: .module),
            systemImage: "paintbrush"
        ) {
            if registry.themes.isEmpty {
                AppEmptyState(
                    icon: "paintbrush",
                    title: LocalizedStringKey(LumiPluginLocalization.string("No themes available", bundle: .module))
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
                                LumiPluginLocalization.string("No themes in this category", bundle: .module)
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
        .appThemedAppearance()
    }

    @ViewBuilder
    private func themeRow(_ theme: LumiUIThemeContribution) -> some View {
        let isSelected = theme.id == registry.selectedThemeId
        AppListRow(isSelected: isSelected, action: {
            try? themeService.selectTheme(id: theme.id)
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
                        .foregroundColor(uiTheme.textSecondary)
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
