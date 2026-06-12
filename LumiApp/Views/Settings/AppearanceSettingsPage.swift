import LumiUI
import SwiftUI

struct AppearanceSettingsPage: View {
    @ObservedObject private var registry: LumiUIThemeRegistry
    private let lumiUIService: LumiUIService

    init(lumiUIService: LumiUIService) {
        self.lumiUIService = lumiUIService
        self.registry = lumiUIService.themeRegistry
    }

    var body: some View {
        AppSettingsContentScaffold {
            AppSettingsSection(title: "主题") {
                ForEach(registry.themes) { theme in
                    GlassSelectionCard(
                        isSelected: registry.selectedThemeId == theme.id,
                        action: {
                            try? lumiUIService.selectTheme(id: theme.id)
                        }
                    ) {
                        HStack(spacing: 12) {
                            Image(systemName: theme.iconName)
                                .foregroundStyle(theme.iconColor)
                                .frame(width: 22)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(theme.displayName)
                                    .font(.appBody)
                                Text(theme.description)
                                    .font(.appCaption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                    }
                }
            }
        }
    }
}
