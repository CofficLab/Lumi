import LumiUI
import SwiftUI

/// Shared ManualView for the Open In plugin family.
public struct OpenInManualView: View {
    @LumiTheme private var theme

    private let displayName: String
    private let toolName: String

    public init(displayName: String, toolName: String) {
        self.displayName = displayName
        self.toolName = toolName
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ManualHeader(
                title: "Open In \(displayName)",
                subtitle: L("User Manual")
            )

            ManualSectionHeader(number: 1, title: L("Overview"))
            Text(L("This manual covers the Open In \(displayName) plugin, which opens the current project or a specified path in \(displayName)."))
                .font(.appBody)
                .foregroundColor(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            ManualSectionHeader(number: 2, title: L("Agent Tool"))
            ManualBulletList(items: [
                .init(L("Tool name: `\(toolName)` — invoke this tool in the chat to open a project.")),
                .init(L("Default target: the current project in Lumi.")),
                .init(L("Optional argument: an absolute path to open a different project or folder.")),
            ])

            ManualSectionHeader(number: 3, title: L("Basic Operations"))
            ManualStepList(items: [
                .init(L("Ask the AI to open the current project in \(displayName).")),
                .init(L("Optionally provide a specific path to open a different folder.")),
                .init(L("The plugin resolves the \(displayName) application and sends the open command.")),
                .init(L("The project opens directly in \(displayName).")),
            ])

            ManualSectionHeader(number: 4, title: L("Notes"))
            ManualBulletList(items: [
                .init(L("\(displayName) must be installed on your Mac for this plugin to work.")),
                .init(L("This is a low-risk action — it only asks the OS to open the target in \(displayName).")),
            ])
        }
        .frame(maxWidth: 620, alignment: .leading)
    }

    private func L(_ key: String) -> String {
        key
    }
}
