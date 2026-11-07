import LumiThemePack
import LumiUI
import SwiftUI

/// 主题包插件「关于」视图：介绍主题库、强调色与系统外观联动能力。
///
/// - macOS：保留落地页式的介绍版式（Hero + 能力网格 + 步骤流），适合桌面窗口的宽幅版面。
/// - iOS：改为原生分组列表 —— 设置里不应出现 Hero banner 与特性网格，
///   改为「主题库 / 能力」两组说明行，与其余设置页保持一致。
///
/// `themeCount` 为实际生效的主题数量：宿主只加载部分主题时，
/// 页面展示的数量随之收敛，而非固定为目录总数。
struct ThemePackAboutView: View {
    /// 实际生效的主题数量。
    let themeCount: Int

    @LumiTheme private var theme

    init(themeCount: Int = LumiThemeCatalog.all.count) {
        self.themeCount = themeCount
    }

    var body: some View {
        #if os(iOS)
        iosBody
        #else
        macBody
        #endif
    }

    // MARK: - macOS

    private var macBody: some View {
        VStack(alignment: .leading, spacing: 22) {
            LandingHero(
                icon: "paintpalette.fill",
                accent: theme.primary,
                tagline: L("A look that feels like yours."),
                chips: [L("Themes"), L("Light/Dark"), L("Accent")],
                metrics: [
                    .init(value: "\(themeCount)", label: L("themes")),
                    .init(value: "1", label: L("click to switch")),
                ]
            )
            .landingAppear()

            LandingSection(title: L("Core Capabilities"), icon: "square.grid.2x2") {
                LandingFeatureGrid(items: [
                    .init(icon: "paintpalette", tint: theme.primary,
                          title: L("Theme Library"),
                          description: L("Switch between built-in light and dark themes.")),
                    .init(icon: "paintbrush.pointed.fill", tint: theme.info,
                          title: L("Accent Colors"),
                          description: L("Personalize the accent used across the UI.")),
                    .init(icon: "circle.lefthalf.filled", tint: theme.warning,
                          title: L("System Sync"),
                          description: L("Follow the system appearance automatically.")),
                ])
            }
            .landingAppear(delay: 0.05)

            LandingSection(title: L("How It Works"), icon: "arrow.triangle.branch.and.merge") {
                LandingStepFlow(steps: [
                    .init(title: L("Pick a theme"), description: L("Choose from the theme library."), icon: "paintpalette"),
                    .init(title: L("Apply"), description: L("The theme is broadcast to the whole app."), icon: "wand.and.stars"),
                    .init(title: L("Persist"), description: L("Your choice is remembered across launches."), icon: "memorychip"),
                ])
            }
            .landingAppear(delay: 0.1)
        }
    }

    // MARK: - iOS

    private var iosBody: some View {
        AppSettingsContentScaffold(maxContentWidth: nil) {
            VStack(alignment: .leading, spacing: 18) {
                AppSettingSection(title: L("Theme Library")) {
                    AppSettingValueRow(
                        L("Themes"),
                        value: "\(themeCount)"
                    )
                }

                AppSettingSection(
                    title: L("Core Capabilities"),
                    footer: L("Your choice is remembered across launches.")
                ) {
                    AppSettingRow(
                        title: L("Theme Library"),
                        description: L("Switch between built-in light and dark themes."),
                        icon: "paintpalette"
                    ) {
                        EmptyView()
                    }

                    AppSettingRow(
                        title: L("Accent Colors"),
                        description: L("Personalize the accent used across the UI."),
                        icon: "paintbrush.pointed.fill"
                    ) {
                        EmptyView()
                    }

                    AppSettingRow(
                        title: L("System Sync"),
                        description: L("Follow the system appearance automatically."),
                        icon: "circle.lefthalf.filled"
                    ) {
                        EmptyView()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func L(_ key: String) -> String {
        LumiPluginLocalization.string(key, bundle: .module)
    }
}

#Preview {
    ScrollView { ThemePackAboutView().padding(22) }
        .frame(width: 560, height: 900)
}
