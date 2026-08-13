import LumiUI
import SwiftUI

/// Hosts 管理插件关于视图 —— 以「配置文件一键切换」为主轴的落地页。
struct HostsManagerAboutView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            hero
            spotlightSection
            capabilitiesSection
            howItWorksSection
        }
    }

    // MARK: - Hero

    private var hero: some View {
        LandingHero(
            icon: "network",
            accent: theme.warning,
            tagline: L("用图形界面管理系统 hosts 文件:多配置切换、一键开关条目、语法校验,告别手改。"),
            chips: [L("配置文件"), L("一键切换"), L("语法高亮"), L("快速开关")],
            metrics: [
                .init(value: "多套", label: L("配置")),
                .init(value: "1键", label: L("开关条目")),
                .init(value: "校验", label: L("语法检查"))
            ]
        )
        .landingAppear()
    }

    // MARK: - 签名特性

    private var spotlightSection: some View {
        LandingSpotlight(
            icon: "rectangle.on.rectangle.angled",
            tint: theme.warning,
            title: L("多套配置,一键切换"),
            message: L("为不同环境(开发 / 测试 / 生产)各建一套 hosts 配置,随时整组切换,无需反复增删行。")
        ) {
            HStack(spacing: 6) {
                AppTag(L("开发"), style: .subtle)
                AppTag(L("测试"), style: .subtle)
                AppTag(L("生产"), style: .subtle)
            }
            .padding(.top, 4)
        }
        .landingAppear(delay: 0.05)
    }

    // MARK: - 核心能力

    private var capabilitiesSection: some View {
        LandingSection(title: L("核心能力"), icon: "square.grid.2x2") {
            LandingFeatureGrid(items: [
                .init(icon: "doc.text", tint: theme.warning,
                      title: L("hosts 管理"),
                      description: L("以友好的界面编辑并管理系统 hosts 文件。")),
                .init(icon: "rectangle.stack", tint: theme.info,
                      title: L("配置文件"),
                      description: L("创建并在多套 hosts 配置之间切换。")),
                .init(icon: "switch.2", tint: theme.success,
                      title: L("快速开关"),
                      description: L("无需删除即可启用或禁用某条 hosts 记录。")),
                .init(icon: "highlighter", tint: theme.primary,
                      title: L("语法高亮"),
                      description: L("对 hosts 条目提供语法高亮与格式校验。"))
            ])
        }
        .landingAppear(delay: 0.1)
    }

    // MARK: - 工作原理

    private var howItWorksSection: some View {
        LandingSection(title: L("工作原理"), icon: "gearshape.2") {
            LandingStepFlow(steps: [
                .init(title: L("编辑条目"), description: L("在界面里增删改 hosts 记录。"), icon: "doc.text"),
                .init(title: L("语法校验"), description: L("保存前校验格式,避免写出无效配置。")),
                .init(title: L("应用到系统"), description: L("把当前配置写入系统 hosts 文件。")),
                .init(title: L("随时切换"), description: L("在不同配置间整组切换或回滚。"))
            ])
        }
        .landingAppear(delay: 0.15)
    }

    // MARK: - Localization

    private func L(_ key: String) -> String {
        LumiPluginLocalization.string(key, bundle: .module)
    }
}

#Preview {
    ScrollView {
        HostsManagerAboutView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
