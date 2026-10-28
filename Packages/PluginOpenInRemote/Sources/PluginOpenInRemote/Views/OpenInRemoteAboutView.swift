import LumiUI
import SwiftUI

/// Open In Remote 插件的「关于」视图。
///
/// 与 Open In 家族共享的落地页不同，本插件打开的是**浏览器中的远程仓库**，
/// 没有「目标应用需要安装」这一前提，因此单独实现一份文案。
struct OpenInRemoteAboutView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            LandingHero(
                icon: OpenInRemoteConstants.systemImage,
                accent: theme.primary,
                tagline: L("Open the current project's remote repository in your browser."),
                chips: [L("Toolbar Button"), L("Remote"), L("Default Browser")],
                metrics: [
                    .init(value: "1", label: L("Agent tool")),
                    .init(value: L("Low"), label: L("Permission risk"))
                ]
            )

            LandingSpotlight(
                icon: "safari",
                tint: theme.primary,
                title: L("Your repository, one click away"),
                message: L("Keep working in Lumi while viewing the current repository's remote on the web.")
            ) {
                AppTag(OpenInRemoteConstants.displayName, style: .accent)
            }

            LandingSection(title: L("Core Capabilities"), icon: "square.grid.2x2") {
                LandingFeatureGrid(items: [
                    .init(
                        icon: "folder",
                        tint: theme.primary,
                        title: L("Current Project"),
                        description: L("Uses the open project as the default target when no path is supplied.")
                    ),
                    .init(
                        icon: "link",
                        tint: theme.info,
                        title: L("Remote URL Aware"),
                        description: L("Reads the origin remote and converts SSH and HTTPS addresses into web links.")
                    ),
                    .init(
                        icon: "lock.shield",
                        tint: theme.success,
                        title: L("Low-Risk Action"),
                        description: L("Only reads the remote address and asks the system to open the browser.")
                    )
                ])
            }

            LandingSection(title: L("How It Works"), icon: "arrow.triangle.branch.and.merge") {
                LandingStepFlow(steps: [
                    .init(title: L("Choose a target"), description: L("Ask the Agent to open the current project, or provide an absolute path."), icon: "scope"),
                    .init(title: L("Read the remote address"), description: L("The plugin reads the origin remote URL of the Git repository."), icon: "link"),
                    .init(title: L("Continue on the web"), description: L("The repository page opens in your default browser."), icon: "checkmark.seal")
                ])
            }
        }
    }

    /// 运行时本地化：SPM 插件 bundle 中 `String(localized:)` 无法正确读取
    /// 编译后的 `.lproj` 资源，统一走 ``LumiLocalization``（见其文档说明）。
    private func L(_ key: String) -> String {
        OpenInRemoteLocalization.string(key)
    }
}
