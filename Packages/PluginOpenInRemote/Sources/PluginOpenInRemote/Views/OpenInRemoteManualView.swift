import LumiUI
import SwiftUI

/// Open In Remote 插件的「使用手册」视图。
struct OpenInRemoteManualView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ManualHeader(
                title: L("Open In Remote"),
                subtitle: L("User Manual")
            )

            ManualSectionHeader(number: 1, title: L("Overview"))
            Text(L("This manual covers the Open In Remote plugin, which opens the remote repository of the current project in your default browser."))
                .font(.appBody)
                .foregroundColor(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            ManualSectionHeader(number: 2, title: L("Agent Tool"))
            ManualBulletList(items: [
                .init(L("Tool name: `open_in_remote` — invoke this tool in the chat to open a remote repository.")),
                .init(L("Default target: the current project in Lumi.")),
                .init(L("Optional argument: an absolute path to open a different project.")),
            ])

            ManualSectionHeader(number: 3, title: L("Basic Operations"))
            ManualStepList(items: [
                .init(L("Ask the AI to open the current project's remote repository.")),
                .init(L("Optionally provide a specific path to open a different repository.")),
                .init(L("The plugin reads the origin remote address and converts it into a web link.")),
                .init(L("The repository page opens directly in your default browser.")),
            ])

            ManualSectionHeader(number: 4, title: L("Notes"))
            ManualBulletList(items: [
                .init(L("The project must be a Git repository with an origin remote that points to a web host.")),
                .init(L("This is a low-risk action — it only reads the remote address and opens the browser.")),
            ])
        }
        .frame(maxWidth: 620, alignment: .leading)
    }

    /// 运行时本地化：SPM 插件 bundle 中 `String(localized:)` 无法正确读取
    /// 编译后的 `.lproj` 资源，统一走 ``LumiLocalization``（见其文档说明）。
    private func L(_ key: String) -> String {
        OpenInRemoteLocalization.string(key)
    }
}
