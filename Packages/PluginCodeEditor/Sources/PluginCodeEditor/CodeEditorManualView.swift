import LumiUI
import SwiftUI

/// Code Editor 插件使用手册。
struct CodeEditorManualView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ManualHeader(
                title: L("Code Editor"),
                subtitle: L("User Manual")
            )

            ManualSectionHeader(number: 1, title: L("Overview"))
            Text(L("Code Editor displays the file currently selected in the project Explorer. The Explorer remains responsible for browsing files; this plugin provides the main editing surface."))
                .font(.appBody)
                .foregroundColor(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            ManualSectionHeader(number: 2, title: L("Open a File"))
            ManualStepList(items: [
                .init(L("Enable Code Editor from the plugin settings if it is disabled.")),
                .init(L("Select Code Editor in the Activity Bar.")),
                .init(L("Open the Explorer rail and select a source file.")),
                .init(L("The editor automatically loads and displays the selected file."))
            ])

            ManualSectionHeader(number: 3, title: L("Edit and Save"))
            ManualBulletList(items: [
                .init(L("Edit the file directly in the main editor area.")),
                .init(L("Syntax highlighting is provided by the shared Editor Host.")),
                .init(L("Press Cmd+S to save the current file.")),
                .init(L("If the selected item is not a text file, the editor shows a non-editable state."))
            ])

            ManualSectionHeader(number: 4, title: L("Behavior"))
            Text(L("The current file comes from ProjectProviding. When another plugin changes the current file, Code Editor receives the change and refreshes its content automatically."))
                .font(.appBody)
                .foregroundColor(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: 620, alignment: .leading)
    }

    private func L(_ key: String) -> String {
        String(localized: String.LocalizationValue(key), bundle: .module)
    }
}

#Preview {
    ScrollView {
        CodeEditorManualView()
            .padding(22)
    }
    .frame(width: 560, height: 820)
}
