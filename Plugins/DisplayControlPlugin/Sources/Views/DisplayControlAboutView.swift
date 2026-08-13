import LumiUI
import SwiftUI

/// 显示器控制插件关于视图 —— 以「能力网格 + 环境要求」为主轴的落地页。
struct DisplayControlAboutView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            hero
            capabilitiesSection
            requirementsSection
        }
    }

    // MARK: - Hero

    private var hero: some View {
        LandingHero(
            icon: "display",
            accent: theme.info,
            tagline: L("在菜单栏直接控制外接显示器:亮度、音量、对比度,通过 DDC/CI 协议精准调节。"),
            chips: [L("亮度"), L("音量"), L("对比度"), L("多显示器")],
            metrics: [
                .init(value: "4", label: L("核心能力")),
                .init(value: "DDC/CI", label: L("控制协议")),
                .init(value: "菜单栏", label: L("操作入口"))
            ]
        )
        .landingAppear()
    }

    // MARK: - 核心能力

    private var capabilitiesSection: some View {
        LandingSection(title: L("核心能力"), icon: "square.grid.2x2") {
            LandingFeatureGrid(items: [
                .init(icon: "sun.max", tint: theme.warning,
                      title: L("亮度控制"),
                      description: L("通过 DDC/CI 协议调节外接显示器亮度。")),
                .init(icon: "speaker.wave.2", tint: theme.info,
                      title: L("音量控制"),
                      description: L("直接从菜单栏控制音频音量。")),
                .init(icon: "circle.righthalf.filled", tint: theme.primary,
                      title: L("对比度调节"),
                      description: L("微调显示器对比度,获得最佳观感。")),
                .init(icon: "rectangle.on.rectangle", tint: theme.success,
                      title: L("多显示器"),
                      description: L("同时管理多台显示器,各自独立控制。"))
            ])
        }
        .landingAppear(delay: 0.05)
    }

    // MARK: - 环境要求

    private var requirementsSection: some View {
        LandingSection(title: L("环境要求"), icon: "checkmark.seal") {
            LandingInventory(tint: theme.info, items: [
                .init(icon: "display", title: L("支持 DDC/CI 的外接显示器")),
                .init(icon: "cable.connector", title: L("兼容的连接方式(HDMI / DisplayPort / USB-C)")),
                .init(icon: "menubar.rectangle", title: L("从菜单栏即可操作"))
            ])
        }
        .landingAppear(delay: 0.1)
    }

    // MARK: - Localization

    private func L(_ key: String) -> String {
        LumiPluginLocalization.string(key, bundle: .module)
    }
}

#Preview {
    ScrollView {
        DisplayControlAboutView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
