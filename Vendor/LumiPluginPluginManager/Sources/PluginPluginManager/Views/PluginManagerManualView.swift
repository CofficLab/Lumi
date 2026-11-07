import LumiUI
import SwiftUI

/// Plugin Manager 插件使用手册
struct PluginManagerManualView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ManualHeader(
                title: L("Plugin Manager"),
                subtitle: L("User Manual")
            )

            ManualSectionHeader(number: 1, title: L("Overview"))
            Text(L("This manual covers the Plugin Manager, which provides a unified interface for browsing, enabling, and configuring all installed plugins."))
                .font(.appBody)
                .foregroundColor(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            ManualSectionHeader(number: 2, title: L("Plugin List"))
            ManualBulletList(items: [
                .init(L("All plugins are listed with their name, description, category, and status.")),
                .init(L("Toggle switch: enable or disable each plugin individually.")),
                .init(L("Click a plugin to view its detail page with about info and settings.")),
            ])

            ManualSectionHeader(number: 3, title: L("Plugin Detail"))
            ManualBulletList(items: [
                .init(L("About section: describes the plugin's features and capabilities.")),
                .init(L("Settings section: plugin-specific configuration options, if any.")),
                .init(L("Status indicator: shows whether the plugin is active, disabled, or in preview.")),
            ])

            ManualSectionHeader(number: 4, title: L("Basic Operations"))
            ManualStepList(items: [
                .init(L("Open Settings → Plugins to access the Plugin Manager.")),
                .init(L("Browse or search the plugin list to find the plugin you want.")),
                .init(L("Toggle the switch to enable or disable a plugin.")),
                .init(L("Click on a plugin name to view its detail page and configure settings.")),
            ])

            ManualSectionHeader(number: 5, title: L("Notes"))
            ManualBulletList(items: [
                .init(L("Some plugins are marked as 'always on' and cannot be disabled.")),
                .init(L("Preview plugins are experimental and may be disabled by default.")),
            ])
        }
        .frame(maxWidth: 620, alignment: .leading)
    }

    private func L(_ key: String) -> String {
        key
    }
}

#Preview {
    ScrollView {
        PluginManagerManualView()
            .padding(22)
    }
    .frame(width: 560, height: 800)
}
