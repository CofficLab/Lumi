import LumiUI
import SwiftUI

/// Quick File Search 插件使用手册
struct QuickFileSearchManualView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ManualHeader(
                title: L("Quick File Search"),
                subtitle: L("User Manual")
            )

            ManualSectionHeader(number: 1, title: L("Overview"))
            Text(L("This manual covers Quick File Search, which provides a Cmd+P style file finder for quickly navigating project files."))
                .font(.appBody)
                .foregroundColor(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            ManualSectionHeader(number: 2, title: L("Activation"))
            ManualBulletList(items: [
                .init(L("Press Cmd+P to open the file search overlay.")),
                .init(L("The overlay appears at the top of the editor area.")),
                .init(L("Press Escape to dismiss without opening a file.")),
            ])

            ManualSectionHeader(number: 3, title: L("Basic Operations"))
            ManualStepList(items: [
                .init(L("Press Cmd+P to open the file search overlay.")),
                .init(L("Start typing to filter files by name — fuzzy matching is supported.")),
                .init(L("Use arrow keys to navigate the results list.")),
                .init(L("Press Enter to open the selected file in the editor.")),
                .init(L("Open Settings → Quick File Search to configure the hotkey and search scope.")),
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
        QuickFileSearchManualView()
            .padding(22)
    }
    .frame(width: 560, height: 800)
}
