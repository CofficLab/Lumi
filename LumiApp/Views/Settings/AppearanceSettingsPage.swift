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
        SettingsPageScaffold(title: "外观", subtitle: "主题由插件提供，App 负责收集并注入 LumiUI") {
            AppSettingsSection(title: "主题") {
                ForEach(registry.themes) { theme in
                    AppSettingsRow(isSelected: registry.selectedThemeId == theme.id) {
                        Button {
                            try? lumiUIService.selectTheme(id: theme.id)
                        } label: {
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

                                Spacer()

                                if registry.selectedThemeId == theme.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
