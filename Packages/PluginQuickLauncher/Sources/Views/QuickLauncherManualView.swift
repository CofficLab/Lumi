import LumiUI
import SwiftUI

/// Quick Launcher 插件使用手册
struct QuickLauncherManualView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ManualHeader(
                title: L("Quick Launcher"),
                subtitle: L("User Manual")
            )

            ManualSectionHeader(number: 1, title: L("Overview"))
            Text(L("This manual covers the Quick Launcher, a Raycast-style global launcher that lets you open apps, files, and Lumi commands with a hotkey."))
                .font(.appBody)
                .foregroundColor(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            ManualSectionHeader(number: 2, title: L("Activation"))
            ManualBulletList(items: [
                .init(L("Use the configured global hotkey (default: Option+Space) to open the launcher from anywhere.")),
                .init(L("The launcher appears as a floating panel at the center of the screen.")),
                .init(L("Press Escape to dismiss the launcher without taking action.")),
            ])

            ManualSectionHeader(number: 3, title: L("Search Sources"))
            ManualBulletList(items: [
                .init(L("Applications: search and open installed apps.")),
                .init(L("Files: find files in the current project with fuzzy matching.")),
                .init(L("Commands: access all Lumi commands from the launcher.")),
            ])

            ManualSectionHeader(number: 4, title: L("Basic Operations"))
            ManualStepList(items: [
                .init(L("Press the global hotkey to open the launcher.")),
                .init(L("Start typing to search across all enabled sources.")),
                .init(L("Use arrow keys to navigate results, Enter to select.")),
                .init(L("Type ? followed by a question to send it directly to the AI.")),
                .init(L("Open Settings → Quick Launcher to configure sources and hotkey.")),
            ])
        }
        .frame(maxWidth: 620, alignment: .leading)
    }

    private func L(_ key: String) -> String {
        LumiPluginLocalization.string(key, bundle: .module)
    }
}

#Preview {
    ScrollView {
        QuickLauncherManualView()
            .padding(22)
    }
    .frame(width: 560, height: 800)
}
